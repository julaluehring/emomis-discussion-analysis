# SEE https://github.com/tweedmann/pol_emo_mDeBERTa2/releases/tag/v.1.0.0

import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
import pytorch_lightning as pl
from torchmetrics import F1Score
from torchmetrics.functional import accuracy, auroc #F1Score #f1
from pytorch_lightning.callbacks import ModelCheckpoint, EarlyStopping
from pytorch_lightning.loggers import TensorBoardLogger
from transformers import AutoTokenizer, DebertaV2Model, AdamW, get_linear_schedule_with_warmup
import pandas as pd
import os
import tqdm
import sys

# set working directory to the pol_emo_mDeBERTa 
os.chdir("./inference/pol_emo_mDeBERTa")
set_directory = os.getcwd()
print("Working directory set to:", set_directory)

# set data directory
src = sys.argv[1] 
file = sys.argv[2]

df = pd.read_csv(os.path.join(src,file), 
                                compression="gzip",
                                usecols=["id", "domain", "text_cleaned"],
                                dtype={"id": int, "domain":str, "text_cleaned":str},
                                #nrows=100000
                )


#define function to apply mDeBERTa model
LABEL_COLUMNS = ['anger_v2', 'fear_v2', 'disgust_v2', 'sadness_v2', 'joy_v2', 'enthusiasm_v2', 'pride_v2', 'hope_v2']
BASE_MODEL_NAME = "microsoft/mdeberta-v3-base"
tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL_NAME)
batch_size = 32
device = "cuda" if torch.cuda.is_available() else "cpu"
print("Process running on:", device)

class CrowdCodedTagger(pl.LightningModule):

  def __init__(self, n_classes: int, n_training_steps=None, n_warmup_steps=None):
    super().__init__()
    self.bert = DebertaV2Model.from_pretrained(BASE_MODEL_NAME, return_dict=True)
    self.classifier = nn.Linear(self.bert.config.hidden_size, n_classes)
    self.n_training_steps = n_training_steps
    self.n_warmup_steps = n_warmup_steps
    self.criterion = nn.BCELoss()

  def forward(self, input_ids, attention_mask, labels=None, token_type_ids=None):
    output = self.bert(input_ids, attention_mask=attention_mask)
    output = self.classifier(output.last_hidden_state[:, 0])
    output = torch.sigmoid(output)
    loss = 0
    if labels is not None:
        loss = self.criterion(output, labels)
    return loss, output

  def training_step(self, batch, batch_idx):
    input_ids = batch["input_ids"]
    attention_mask = batch["attention_mask"]
    labels = batch["labels"]
    loss, outputs = self(input_ids, attention_mask, labels)
    self.log("train_loss", loss, prog_bar=True, logger=True)
    return {"loss": loss, "predictions": outputs, "labels": labels}

  def validation_step(self, batch, batch_idx):
    input_ids = batch["input_ids"]
    attention_mask = batch["attention_mask"]
    labels = batch["labels"]
    loss, outputs = self(input_ids, attention_mask, labels)
    self.log("val_loss", loss, prog_bar=True, logger=True)
    return loss

  def test_step(self, batch, batch_idx):
    input_ids = batch["input_ids"]
    attention_mask = batch["attention_mask"]
    labels = batch["labels"]
    loss, outputs = self(input_ids, attention_mask, labels)
    self.log("test_loss", loss, prog_bar=True, logger=True)
    return loss

  def training_epoch_end(self, outputs):

    labels = []
    predictions = []
    for output in outputs:
      for out_labels in output["labels"].detach().cpu():
        labels.append(out_labels)
      for out_predictions in output["predictions"].detach().cpu():
        predictions.append(out_predictions)

    labels = torch.stack(labels).int()
    predictions = torch.stack(predictions)

    for i, name in enumerate(LABEL_COLUMNS):
      class_roc_auc = auroc(predictions[:, i], labels[:, i])
      self.logger.experiment.add_scalar(f"{name}_roc_auc/Train", class_roc_auc, self.current_epoch)

  def configure_optimizers(self):

    optimizer = AdamW(self.parameters(), lr=2e-5) #DEFINING LEARNING RATE

    scheduler = get_linear_schedule_with_warmup(
      optimizer,
      num_warmup_steps=self.n_warmup_steps,
      num_training_steps=self.n_training_steps
    )

    return dict(
      optimizer=optimizer,
      lr_scheduler=dict(
        scheduler=scheduler,
        interval='step'
      )
    )

# define function for inference
def predict_labels(df):
    input_text = df["text_cleaned"].tolist()
    num_inputs = len(input_text)
    num_batches = (num_inputs - 1) // batch_size + 1

    try:
        for i, batch in enumerate(tqdm.tqdm(range(num_batches))):
            start_idx = i * batch_size
            end_idx = min((i + 1) * batch_size, num_inputs)
            batch_text = input_text[start_idx:end_idx]

            encoded_input = tokenizer(batch_text, padding=True, truncation=True, max_length=280, return_tensors='pt')
            outputs = model(**encoded_input.to(device))

            tensor_values = outputs[1].tolist()
            decimal_numbers = [[num for num in sublist] for sublist in tensor_values]

            output_df = pd.DataFrame(decimal_numbers, columns=LABEL_COLUMNS)
            input_df = df.iloc[start_idx:end_idx].reset_index(drop=True)
            output_df = pd.concat([input_df, output_df], axis=1)

            # Append to an existing CSV file or create a new one
            output_df.to_csv(os.path.join(src, 'emotion_inference.csv.gz'), mode='a', index=False, header=not os.path.exists(os.path.join(src, 'emotion_inference.csv.gz')), compression="gzip")

    except KeyboardInterrupt:
        print("KeyboardInterrupt.")
        return

# put model into evaluation mode and load local fine-tuned model
model = CrowdCodedTagger(n_classes=8)
model.load_state_dict(torch.load("./model/pytorch_model.pt"), strict = False)
model.to(device)
model.eval()

predict_labels(df)
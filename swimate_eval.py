import numpy as np
import tensorflow as tf
from sklearn.metrics import confusion_matrix, classification_report
import matplotlib.pyplot as plt
import pandas as pd

model = tf.keras.models.load_model("swimate_model.h5")
labels = np.load("labels.npy", allow_pickle=True)

def load_sequence(csv_path):
    df = pd.read_csv(csv_path)
    seq = df[["accel_x","accel_y","accel_z",
              "gyro_x","gyro_y","gyro_z"]].values
    return seq

def evaluate_model(csv_folder, seq_len):
    import glob, os

    preds = []
    trues = []

    csv_files = glob.glob(os.path.join(csv_folder, "*.csv"))

    for f in csv_files:
        seq = load_sequence(f)

        padded = np.zeros((1, seq_len, seq.shape[1]))
        length = min(len(seq), seq_len)
        padded[0, :length, :] = seq[:length]

        pred_idx = np.argmax(model.predict(padded), axis=1)[0]
        true_label = pd.read_csv(f)["label"].iloc[0]

        preds.append(pred_idx)
        trues.append(np.where(labels==true_label)[0][0])

    cm = confusion_matrix(trues, preds)
    print("Confusion Matrix:\n", cm)

    print("\nClassification Report:")
    print(classification_report(trues, preds, target_names=labels))

    plt.imshow(cm, cmap='Blues')
    plt.title("Evaluation Confusion Matrix")
    plt.colorbar()
    plt.savefig("evaluation_confusion.png")
    plt.close()

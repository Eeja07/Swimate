import os
import glob
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import confusion_matrix
import matplotlib.pyplot as plt
from datetime import datetime

print("Num GPUs Available:", len(tf.config.list_physical_devices('GPU')))
plt.switch_backend("Agg")  # allows PNG saving during training

# ============================================================
# Create run directory
# ============================================================
timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
run_dir = os.path.join("runs", timestamp)
os.makedirs(run_dir, exist_ok=True)
print(f"Saving outputs to: {run_dir}")

# ============================================================
# Augmentation functions
# ============================================================
GAUSSIAN_STD = 0.05
MAG_SCALE_STD = 0.10

def add_gaussian_noise(x):
    noise = np.random.normal(0, GAUSSIAN_STD, x.shape)
    return x + noise

def magnitude_scaling(x):
    scale = np.random.normal(1.0, MAG_SCALE_STD)
    return x * scale

def augment_window(x):
    if np.random.rand() < 0.5:
        return add_gaussian_noise(x)
    else:
        return magnitude_scaling(x)

# ============================================================
# Window slicing
# ============================================================
def window_sequence(data, labels, window=128, stride=64):
    X, y = [], []

    for seq, lbl in zip(data, labels):
        L = len(seq)
        if L < window:
            continue
        for i in range(0, L - window + 1, stride):
            X.append(seq[i:i+window])
            y.append(lbl)

    return np.array(X), np.array(y)

# ============================================================
# Load dataset
# ============================================================
def load_all_csv(csv_folder):
    sequences = []
    labels = []

    csv_files = glob.glob(os.path.join(csv_folder, "*.csv"))

    for f in csv_files:
        df = pd.read_csv(f)
        imu = df[["accel_x","accel_y","accel_z","gyro_x","gyro_y","gyro_z"]].values
        label = df["label"].iloc[0]

        sequences.append(imu)
        labels.append(label)

    return sequences, labels


csv_folder = "dataset"
seqs, lbls = load_all_csv(csv_folder)

label_encoder = LabelEncoder()
lbls = label_encoder.fit_transform(lbls)
np.save(os.path.join(run_dir, "labels.npy"), label_encoder.classes_)

# Window → dataset
X, y = window_sequence(seqs, lbls)
print("Windowed shape:", X.shape)

seq_len = X.shape[1]
feature_dim = X.shape[2]
num_classes = len(np.unique(y))

# Train/val split
X_train, X_val, y_train, y_val = train_test_split(
    X, y, test_size=0.2, stratify=y, random_state=42
)

print("Train dist:", np.unique(y_train, return_counts=True))
print("Val dist:", np.unique(y_val, return_counts=True))

# ============================================================
# Apply augmentation to training windows
# ============================================================
augmented = []
aug_labels = []

for i in range(len(X_train)):
    augmented.append(augment_window(X_train[i]))
    aug_labels.append(y_train[i])

X_train = np.concatenate([X_train, np.array(augmented)], axis=0)
y_train = np.concatenate([y_train, np.array(aug_labels)], axis=0)

print("After augmentation:", X_train.shape)

# ============================================================
# Transformer block
# ============================================================
def transformer_block(x, num_heads=4, key_dim=32, ff_dim=128):
    attn = tf.keras.layers.MultiHeadAttention(
        num_heads=num_heads, key_dim=key_dim
    )(x, x)

    x = tf.keras.layers.Add()([x, attn])
    x = tf.keras.layers.LayerNormalization()(x)

    ff = tf.keras.Sequential([
        tf.keras.layers.Dense(ff_dim, activation="relu"),
        tf.keras.layers.Dense(x.shape[-1])
    ])(x)

    x = tf.keras.layers.Add()([x, ff])
    x = tf.keras.layers.LayerNormalization()(x)

    return x

# ============================================================
# Build model
# ============================================================
def build_transformer(seq_len, feature_dim, num_classes, depth=2):
    inp = tf.keras.Input(shape=(seq_len, feature_dim))

    x = tf.keras.layers.Dense(128)(inp)

    for _ in range(depth):
        x = transformer_block(x)

    x = tf.keras.layers.GlobalAveragePooling1D()(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    out = tf.keras.layers.Dense(num_classes, activation="softmax")(x)

    return tf.keras.Model(inp, out)


model = build_transformer(seq_len, feature_dim, num_classes)
model.summary()

model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-3),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)

# # ============================================================
# # Callback for LIVE confusion matrix per epoch
# # ============================================================
# class ConfusionMatrixCallback(tf.keras.callbacks.Callback):
#     def on_epoch_end(self, epoch, logs=None):
#         preds = np.argmax(self.model.predict(X_val), axis=1)
#         cm = confusion_matrix(y_val, preds)
#         cm_pct = cm.astype(float) / cm.sum(axis=1)[:, None] * 100

#         plt.figure(figsize=(8,6))
#         plt.imshow(cm_pct, cmap="Blues", vmin=0, vmax=100)
#         plt.colorbar(label="Percentage")

#         classes = label_encoder.classes_
#         ticks = np.arange(len(classes))
#         plt.xticks(ticks, classes, rotation=45)
#         plt.yticks(ticks, classes)

#         for i in range(cm_pct.shape[0]):
#             for j in range(cm_pct.shape[1]):
#                 plt.text(j, i, f"{cm_pct[i,j]:.1f}%",
#                          ha="center",
#                          color="white" if cm_pct[i,j] > 50 else "black")

#         plt.title(f"Confusion Matrix - Epoch {epoch+1}")
#         plt.xlabel("Predicted")
#         plt.ylabel("True")
#         plt.tight_layout()
#         plt.savefig(os.path.join(run_dir, f"confusion_matrix_epoch_{epoch+1}.png"))
#         plt.close()

# ============================================================
# Train
# ============================================================
history = model.fit(
    X_train, y_train,
    epochs=50,
    batch_size=32,
    validation_data=(X_val, y_val),
    # callbacks=[
    #     ConfusionMatrixCallback(),
    #     tf.keras.callbacks.EarlyStopping(patience=6, restore_best_weights=True)
    callbacks=[
    tf.keras.callbacks.EarlyStopping(patience=6, restore_best_weights=True)
    ]
)


# ============================================================
# Final Confusion Matrix
# ============================================================
preds = np.argmax(model.predict(X_val), axis=1)
cm = confusion_matrix(y_val, preds)
cm_pct = cm.astype(float) / cm.sum(axis=1)[:, None] * 100

plt.figure(figsize=(8,6))
plt.imshow(cm_pct, cmap="Blues", vmin=0, vmax=100)
plt.colorbar(label="Percentage")

classes = label_encoder.classes_
ticks = np.arange(len(classes))
plt.xticks(ticks, classes, rotation=45)
plt.yticks(ticks, classes)

for i in range(cm_pct.shape[0]):
    for j in range(cm_pct.shape[1]):
        plt.text(j, i, f"{cm_pct[i,j]:.1f}%",
                 ha="center",
                 color="white" if cm_pct[i,j] > 50 else "black")

plt.title("Final Confusion Matrix")
plt.xlabel("Predicted")
plt.ylabel("True")
plt.tight_layout()
plt.savefig(os.path.join(run_dir, "confusion_matrix_final.png"))
plt.close()

print("Confusion matrix saved.")


# ============================================================
# Training curves PNG
# ============================================================
plt.figure(figsize=(10,5))
plt.subplot(1,2,1)
plt.plot(history.history["accuracy"], label="train acc")
plt.plot(history.history["val_accuracy"], label="val acc")
plt.legend()
plt.title("Accuracy")

plt.subplot(1,2,2)
plt.plot(history.history["loss"], label="train loss")
plt.plot(history.history["val_loss"], label="val loss")
plt.legend()
plt.title("Loss")

plt.tight_layout()
plt.savefig(os.path.join(run_dir, "training_curves.png"))
plt.close()


# ============================================================
# Save models
# ============================================================
keras_path = os.path.join(run_dir, "swimate_model.h5")
tflite_path = os.path.join(run_dir, "swimate_model.tflite")

model.save(keras_path)
print("Keras model saved:", keras_path)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite = converter.convert()
with open(tflite_path, "wb") as f:
    f.write(tflite)

print("TFLite saved:", tflite_path)

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

# ============================================================
# Create run directory
# ============================================================
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
run_dir = os.path.join("runs_no_aug", "run_"+timestamp)
os.makedirs(run_dir, exist_ok=True)
print(f"Saving outputs to: {run_dir}")

# ============================================================
# Window slicing function
# ============================================================
def window_sequence(data, labels, window=128, stride=64):
    X = []
    y = []

    for seq, label in zip(data, labels):
        L = len(seq)
        if L < window:
            continue

        for i in range(0, L - window + 1, stride):
            X.append(seq[i:i+window])
            y.append(label)

    return np.array(X), np.array(y)


# ============================================================
# Load dataset from CSV
# ============================================================
def load_all_csv(csv_folder):
    data_list = []
    label_list = []

    csv_files = glob.glob(os.path.join(csv_folder, "*.csv"))

    for f in csv_files:
        df = pd.read_csv(f)

        imu_data = df[["accel_x", "accel_y", "accel_z",
                       "gyro_x", "gyro_y", "gyro_z"]].values

        label = df["label"].iloc[0]

        data_list.append(imu_data)
        label_list.append(label)

    return data_list, label_list


csv_folder = "dataset"
data_list, label_list = load_all_csv(csv_folder)

label_encoder = LabelEncoder()
labels = label_encoder.fit_transform(label_list)
np.save(os.path.join(run_dir, "labels.npy"), label_encoder.classes_)

# ============================================================
# Convert sequences → fixed windows
# ============================================================
X, y = window_sequence(data_list, labels, window=128, stride=64)
print("Windowed dataset shape:", X.shape, y.shape)

seq_len = X.shape[1]
feature_dim = X.shape[2]
num_classes = len(np.unique(y))

# ============================================================
# Train/Val split 
# ============================================================
X_train, X_val, y_train, y_val = train_test_split(
    X, y,
    test_size=0.2,
    random_state=42,
    stratify=y
)

print("Train distribution:", np.unique(y_train, return_counts=True))
print("Val distribution:", np.unique(y_val, return_counts=True))

# ============================================================
# Transformer Block
# ============================================================
def transformer_block(x, num_heads=4, key_dim=32, ff_dim=128):
    attn_output = tf.keras.layers.MultiHeadAttention(
        num_heads=num_heads,
        key_dim=key_dim
    )(x, x)

    x = tf.keras.layers.Add()([x, attn_output])
    x = tf.keras.layers.LayerNormalization(epsilon=1e-6)(x)

    ff = tf.keras.Sequential([
        tf.keras.layers.Dense(ff_dim, activation="relu"),
        tf.keras.layers.Dense(x.shape[-1])
    ])(x)

    x = tf.keras.layers.Add()([x, ff])
    x = tf.keras.layers.LayerNormalization(epsilon=1e-6)(x)

    return x


# ============================================================
# Build Transformer model
# ============================================================
def build_transformer(seq_len, feature_dim, num_classes, depth=2):
    inputs = tf.keras.Input(shape=(seq_len, feature_dim))

    x = tf.keras.layers.Dense(128)(inputs)  # embed IMU features

    for _ in range(depth):
        x = transformer_block(x)

    x = tf.keras.layers.GlobalAveragePooling1D()(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax")(x)

    model = tf.keras.Model(inputs, outputs)
    return model


model = build_transformer(seq_len, feature_dim, num_classes)
model.summary()

model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-3),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)

# ============================================================
# Train
# ============================================================
history = model.fit(
    X_train, y_train,
    epochs=50,
    batch_size=32,
    validation_data=(X_val, y_val),
    callbacks=[
        tf.keras.callbacks.EarlyStopping(
            patience=6, restore_best_weights=True
        )
    ]
)

# ============================================================
# Save Keras model
# ============================================================
model_path = os.path.join(run_dir, "swimate_model.h5")
model.save(model_path)

print("Model saved:", model_path)

# ============================================================
# Confusion Matrix
# ============================================================
y_pred = np.argmax(model.predict(X_val), axis=1)
cm = confusion_matrix(y_val, y_pred)
cm_pct = cm.astype(float) / cm.sum(axis=1)[:, None] * 100

plt.figure(figsize=(8, 6))
plt.imshow(cm_pct, cmap="Blues", vmin=0, vmax=100)
plt.colorbar(label="Percentage")

classes = label_encoder.classes_
ticks = np.arange(len(classes))

plt.xticks(ticks, classes, rotation=45)
plt.yticks(ticks, classes)

# Text values
for i in range(cm_pct.shape[0]):
    for j in range(cm_pct.shape[1]):
        plt.text(j, i, f"{cm_pct[i,j]:.1f}%",
                 ha='center',
                 color="white" if cm_pct[i,j] > 50 else "black")

plt.title("Confusion Matrix (%)")
plt.xlabel("Predicted")
plt.ylabel("True")
plt.tight_layout()
plt.savefig(os.path.join(run_dir, "confusion_matrix.png"))
plt.close()

# ============================================================
# Save TFLite model
# ============================================================
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite = converter.convert()

with open(os.path.join(run_dir, "swimate_model.tflite"), "wb") as f:
    f.write(tflite)

print("TFLite model saved.")

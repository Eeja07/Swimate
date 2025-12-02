import os
import glob
import numpy as np
import pandas as pd
import tensorflow as tf
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import confusion_matrix
from sklearn.utils.class_weight import compute_class_weight
from datetime import datetime

plt.switch_backend("Agg")
print("Num GPUs Available:", len(tf.config.list_physical_devices('GPU')))

# ===========================
# Settings
# ===========================
DATA_DIR = "dataset"
SAMPLING_HZ = 10      # Hz
WINDOW_SEC = 5         # 2-second windows
WINDOW_SIZE = int(SAMPLING_HZ * WINDOW_SEC)
STRIDE = WINDOW_SIZE // 2

GAUSSIAN_STD = 0.05
MAG_SCALE_STD = 0.1
EPOCHS = 60
BATCH_SIZE = 32

timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
run_dir = os.path.join("runs", timestamp)
os.makedirs(run_dir, exist_ok=True)

# ===========================
# Augmentation functions
# ===========================
def add_gaussian_noise(x):
    return x + np.random.normal(0, GAUSSIAN_STD, x.shape)

def magnitude_scaling(x):
    return x * np.random.normal(1.0, MAG_SCALE_STD)

def axis_scaling(x):
    return x * np.random.uniform(0.85, 1.15, size=(1, x.shape[1]))

def random_dropout(x, drop_prob=0.05):
    mask = (np.random.rand(*x.shape) > drop_prob).astype(float)
    return x * mask

def augment_window(x):
    if np.random.rand() < 0.7: x = add_gaussian_noise(x)
    if np.random.rand() < 0.7: x = magnitude_scaling(x)
    if np.random.rand() < 0.5: x = axis_scaling(x)
    if np.random.rand() < 0.5: x = random_dropout(x)
    return x

# ===========================
# Window slicing
# ===========================
def window_sequence(seq, label, window=WINDOW_SIZE, stride=STRIDE):
    out_x, out_y = [], []
    L = len(seq)
    if L < window: return [], []
    for i in range(0, L - window + 1, stride):
        out_x.append(seq[i:i+window])
        out_y.append(label)
    return out_x, out_y

# ===========================
# Load CSV dataset
# ===========================
def load_all_csv(path):
    seqs, labels = [], []
    for f in sorted(glob.glob(os.path.join(path, "*.csv"))):
        df = pd.read_csv(f)
        df.columns = df.columns.str.strip().str.lower()  # normalize columns

        sensor_cols = ["accel_x","accel_y","accel_z","gyro_x","gyro_y","gyro_z"]
        df_sensors = df[sensor_cols].astype(float)

        # Label: either CSV column or inferred from filename
        if "label" in df.columns:
            label = df["label"].iloc[0].strip().lower()
        else:
            fname = os.path.basename(f).lower()
            label = "swimming" if "swimming" in fname else "not swimming"

        seqs.append(df_sensors.values)
        labels.append(label)
    return seqs, labels

seqs, lbls = load_all_csv(DATA_DIR)
print("Loaded raw sequences:", len(seqs))

# ===========================
# Encode labels
# ===========================
# Lowercase all labels for consistency
lbls = [l.lower() for l in lbls]
encoder = LabelEncoder()
labels_enc = encoder.fit_transform(lbls)
np.save(os.path.join(run_dir, "labels.npy"), encoder.classes_)

# ===========================
# Window known classes
# ===========================
X_list, y_list = [], []
for seq, lbl in zip(seqs, labels_enc):
    xs, ys = window_sequence(seq, lbl)
    X_list += xs
    y_list += ys

X = np.array(X_list)
y = np.array(y_list)
print("Known-class windows:", X.shape)

# ===========================
# Generate UNKNOWN windows
# ===========================
def generate_unknown(X_known, num=400):
    unknown = []
    n = len(X_known)
    for _ in range(num):
        a = X_known[np.random.randint(0, n)]
        b = X_known[np.random.randint(0, n)]
        alpha = np.random.uniform(0.3, 0.7)
        mix = alpha * a + (1 - alpha) * b
        mix += np.random.normal(0, 0.15, mix.shape)
        unknown.append(mix)
    return np.array(unknown)

unknown_windows = generate_unknown(X, num=500)

# Add unknown class if missing
if "not swimming" not in encoder.classes_:
    encoder.classes_ = np.append(encoder.classes_, "not swimming")
unknown_idx = np.where(encoder.classes_ == "not swimming")[0][0]

X = np.concatenate([X, unknown_windows], axis=0)
y = np.concatenate([y, np.full(len(unknown_windows), unknown_idx)])
print("Total windows after NOT SWIMMING added:", X.shape)

# ===========================
# Train/val split
# ===========================
X_train, X_val, y_train, y_val = train_test_split(
    X, y, test_size=0.2, stratify=y, random_state=42
)

# ===========================
# Class weights
# ===========================
class_weights = compute_class_weight(class_weight='balanced',
                                     classes=np.unique(y_train),
                                     y=y_train)
class_weight_dict = {i:w for i,w in enumerate(class_weights)}
print("Class weights:", class_weight_dict)

# ===========================
# Data generator with augmentation
# ===========================
def data_generator(X, y, batch_size=BATCH_SIZE, augment=True):
    n = len(X)
    while True:
        idx = np.random.permutation(n)
        for i in range(0, n, batch_size):
            batch_idx = idx[i:i+batch_size]
            batch_x = X[batch_idx].copy()
            batch_y = y[batch_idx]
            if augment:
                batch_x = np.array([augment_window(w) for w in batch_x])
            yield batch_x, batch_y

train_gen = data_generator(X_train, y_train)
val_gen = data_generator(X_val, y_val, augment=False)

# ===========================
# Transformer model
# ===========================
def transformer_block(x):
    attn = tf.keras.layers.MultiHeadAttention(num_heads=4, key_dim=32, dropout=0.2)(x, x)
    x = tf.keras.layers.Add()([x, attn])
    x = tf.keras.layers.LayerNormalization()(x)
    ff = tf.keras.Sequential([
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(x.shape[-1])
    ])(x)
    x = tf.keras.layers.Add()([x, ff])
    return tf.keras.layers.LayerNormalization()(x)

def build_model(seq_len, feat_dim, num_classes):
    inp = tf.keras.Input((seq_len, feat_dim))
    x = tf.keras.layers.Dense(128)(inp)
    for _ in range(3):
        x = transformer_block(x)
    x = tf.keras.layers.GlobalAveragePooling1D()(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    out = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    return tf.keras.Model(inp, out)

model = build_model(WINDOW_SIZE, 6, len(encoder.classes_))
model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-3),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)

# ===========================
# Training
# ===========================
steps_per_epoch = len(X_train) // BATCH_SIZE
val_steps = len(X_val) // BATCH_SIZE

history = model.fit(
    train_gen,
    steps_per_epoch=steps_per_epoch,
    validation_data=val_gen,
    validation_steps=val_steps,
    epochs=EPOCHS,
    class_weight=class_weight_dict,
    callbacks=[tf.keras.callbacks.EarlyStopping(patience=6, restore_best_weights=True)]
)

model.save(os.path.join(run_dir, "model.h5"), save_format="h5")

# ===========================
# Confusion matrix (5-class)
# ===========================
fixed_classes = ["freestyle", "backstroke", "breaststroke", "butterfly", "not swimming"]
class_map = {name: i for i, name in enumerate(fixed_classes)}

# Map predictions and y_val to fixed classes indices
y_val_mapped = np.array([class_map[encoder.classes_[i]] if encoder.classes_[i] in class_map else class_map["not swimming"] for i in y_val])
preds = np.argmax(model.predict(X_val), axis=1)
preds_mapped = np.array([class_map[encoder.classes_[i]] if encoder.classes_[i] in class_map else class_map["not swimming"] for i in preds])

cm = confusion_matrix(y_val_mapped, preds_mapped)
cm_pct = cm.astype(float) / cm.sum(axis=1, keepdims=True) * 100

plt.figure(figsize=(8,6))
plt.imshow(cm_pct, cmap="Blues", vmin=0, vmax=100)
plt.colorbar(label="Correct (%)")
ticks = np.arange(len(fixed_classes))
plt.xticks(ticks, fixed_classes, rotation=45)
plt.yticks(ticks, fixed_classes)

for i in range(cm_pct.shape[0]):
    for j in range(cm_pct.shape[1]):
        plt.text(j, i, f"{cm_pct[i,j]:.1f}%", ha="center",
                 color="white" if cm_pct[i,j] > 50 else "black")

plt.title("Confusion Matrix")
plt.tight_layout()
plt.savefig(os.path.join(run_dir, "confusion_matrix.png"))
plt.close()

import os
import glob
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import confusion_matrix
import matplotlib.pyplot as plt

print("Num GPUs Available: ", len(tf.config.list_physical_devices('GPU')))


def load_all_csv(csv_folder):
    data_list = []
    label_list = []

    csv_files = glob.glob(os.path.join(csv_folder, "*.csv"))

    for f in csv_files:
        df = pd.read_csv(f)

        imu_data = df[["accel_x","accel_y","accel_z","gyro_x","gyro_y","gyro_z"]].values
        data_list.append(imu_data)
        label_list.append(df["label"].iloc[0])  

    return data_list, label_list


def pad_sequences(seqs):
    max_len = max(len(s) for s in seqs)
    padded = np.zeros((len(seqs), max_len, seqs[0].shape[1]))
    
    for i, seq in enumerate(seqs):
        padded[i, :len(seq), :] = seq

    return padded, max_len


def build_transformer_model(seq_len, feature_dim, num_classes):
    inputs = tf.keras.Input(shape=(seq_len, feature_dim))

    x = tf.keras.layers.LayerNormalization()(inputs)
    x = tf.keras.layers.MultiHeadAttention(num_heads=4, key_dim=32)(x, x)
    x = tf.keras.layers.Dropout(0.2)(x)
    x = tf.keras.layers.GlobalAveragePooling1D()(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax")(x)

    model = tf.keras.Model(inputs, outputs)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-4),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )
    return model


csv_folder = "dataset"  # change this if needed

data_list, label_list = load_all_csv(csv_folder)

label_encoder = LabelEncoder()
labels = label_encoder.fit_transform(label_list)

X, seq_len = pad_sequences(data_list)
y = np.array(labels)

feature_dim = X.shape[2]
num_classes = len(np.unique(y))

X_train, X_val, y_train, y_val = train_test_split(
    X, y, test_size=0.4, random_state=42, stratify=y
)


model = build_transformer_model(seq_len, feature_dim, num_classes)
model.summary()

history = model.fit(
    X_train, y_train,
    epochs=25,
    batch_size=16,
    validation_data=(X_val, y_val),
    callbacks=[
        tf.keras.callbacks.EarlyStopping(
            patience=5, restore_best_weights=True
        )
    ]
)


model.save("swimate_model.h5")
print("Transformer Model saved as swimate_model.h5")


y_pred = np.argmax(model.predict(X_val), axis=1)
cm = confusion_matrix(y_val, y_pred)

plt.figure(figsize=(6, 5))
plt.imshow(cm, cmap="Blues")
plt.title("Confusion Matrix")
plt.colorbar()
plt.savefig("confusion_matrix.png")
plt.close()

print("Confusion matrix saved.")


converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open("swimate_model.tflite", "wb") as f:
    f.write(tflite_model)

print("TFLite model saved as swimate_model.tflite")


def realtime_inference_tflite(sequence, interpreter_path="swimate_model.tflite"):
    interpreter = tf.lite.Interpreter(model_path=interpreter_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    padded = np.zeros((1, seq_len, feature_dim))
    length = min(len(sequence), seq_len)
    padded[0, :length, :] = sequence[:length]

    interpreter.set_tensor(input_details[0]['index'], padded.astype(np.float32))
    interpreter.invoke()

    pred = interpreter.get_tensor(output_details[0]['index'])
    idx = np.argmax(pred)

    return label_encoder.inverse_transform([idx])[0]
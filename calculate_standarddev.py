import pandas as pd
import numpy as np

def calculate_standard_deviation(csv_file):
    df = pd.read_csv(csv_file)
    imu_data = df[["accel_x","accel_y","accel_z","gyro_x","gyro_y","gyro_z"]]
    std_dev = imu_data.std()
    return std_dev

if __name__ == "__main__":
    csv_file = "freestyle_dataset.csv" 
    # csv_file = "backstroke_dataset.csv"
    std_dev = calculate_standard_deviation(csv_file)
    print("Standard Deviation of IMU data:")
    print(std_dev)
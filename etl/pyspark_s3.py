import logging
import random

from pyspark.sql import SparkSession

# Setup Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("NYC311_Data_Partitioner")


def generate_random_splits(total_records, data_record_split_num):
    random_numbers = [
        random.randint(1, 100) for _ in range(data_record_split_num)
    ]
    total_random = sum(random_numbers)
    # Scale each random number to the correct portion of total_records
    split_sizes = [
        round((num / total_random) * total_records) for num in random_numbers
    ]

    # Fix rounding issue: adjust the last split to ensure total matches
    split_sizes[-1] = total_records - sum(split_sizes[:-1])

    return split_sizes


def load_csv_and_upload_to_s3_as_parquet(
    s3_source, s3_output_dir, data_record_split_num=5
):
    """
    Splits a CSV dataset into multiple Parquet files
    and uploads them to an S3(AWS) bucket using PySpark.

    Args:
        s3_source (str):
        The S3 path to the input CSV file.
        s3_output_dir (str):
        The target S3 directory to store the Parquet files.
        data_record_split_num (int):
        The number of chunks to split the dataset into. Default is 5.

    Returns:
        None
    """

    # Initialize Spark Session
    spark = (
        SparkSession.builder.appName("NYC311 Parquet S3 Partitioner")
        .config(
            "spark.hadoop.fs.s3a.impl",
            "org.apache.hadoop.fs.s3a.S3AFileSystem",
        )
        .config(
            "spark.hadoop.fs.s3a.aws.credentials.provider",
            "org.apache.hadoop.fs.s3a.auth.IAMInstanceCredentialsProvider",
        )
        .getOrCreate()
    )

    try:
        logger.info(f"Loading dataset from {s3_source}")

        df = spark.read.option("header", True).csv(s3_source)

        # count number of ingested records
        total_records = df.count()

        logger.info(f"Total records loaded: {total_records}")

        split_sizes = generate_random_splits(
            total_records, data_record_split_num
        )

        current_index = 0

        for idx, size in enumerate(split_sizes):
            if idx == data_record_split_num - 1:
                df_partition = df.subtract(df.limit(current_index))
            else:
                df_partition = df.limit(current_index + size).subtract(
                    df.limit(current_index)
                )

            # output_path = f"{s3_output_dir}/nyc_311_{idx + 1}.parquet"
            partition_record_count = df_partition.count()

            if partition_record_count == 0:
                logger.warning(
                    f"Partition nyc_311_{idx + 1} has no data. Skipping"
                )
                continue

            df_partition.write.mode("overwrite").parquet(s3_output_dir)
            logger.info(
                f"""Partition nyc_311_{idx + 1}:
                Saved {partition_record_count} records to {s3_output_dir}"""
            )

            current_index += size

        logger.info("All parquet data written to S3 successfully.")

    except Exception as e:
        logger.error(f"Error while partitioning and uploading: {str(e)}")

    finally:
        spark.stop()
        logger.info("Spark session stopped")


load_csv_and_upload_to_s3_as_parquet(
    s3_source="/movie",
    s3_output_dir="/output",
    data_record_split_num=5,
)

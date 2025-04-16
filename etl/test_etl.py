import random

from pyspark.sql import SparkSession
from pyspark.sql.functions import udf
from pyspark.sql.types import FloatType, IntegerType, StringType


# Define UDFs for generating random data
@udf(StringType())
def random_name():
    return random.choice(["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"])


@udf(IntegerType())
def random_age():
    return random.randint(18, 60)


@udf(FloatType())
def random_salary():
    return round(random.uniform(30000, 150000), 2)


def main():
    spark = SparkSession.builder.appName("Generate5MillionRows").getOrCreate()

    row_count = 5_000_000

    # Create base DataFrame with sequential IDs
    df = spark.range(0, row_count).withColumnRenamed("id", "user_id")

    # Add columns with random data
    df = df.withColumn("name", random_name())
    df = df.withColumn("age", random_age())
    df = df.withColumn("salary", random_salary())

    # Write as Parquet to S3 (update bucket path!)
    df.write.mode("overwrite").parquet(
        "s3://big-data-bck/data/5million_rows.parquet"
    )

    spark.stop()


if __name__ == "__main__":
    main()

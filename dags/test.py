from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.dummy import DummyOperator
from airflow.operators.python import PythonOperator

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}


dag = DAG(
    "simple_addition_dag",
    default_args=default_args,
    description="A simple DAG with addition task",
    schedule_interval=timedelta(days=1),
    start_date=datetime(2025, 4, 14),
    catchup=False,
)


def perform_addition(a, b, **kwargs):
    result = a + b
    print(f"The result of the calculation is {a} + {b} = {result}")
    return result


start = DummyOperator(
    task_id="start",
    dag=dag,
)

addition_task = PythonOperator(
    task_id="addition_task",
    python_callable=perform_addition,
    op_kwargs={"a": 5, "b": 3},
    dag=dag,
)

end = DummyOperator(
    task_id="end",
    dag=dag,
)


start >> addition_task >> end

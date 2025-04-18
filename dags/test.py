from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.empty import EmptyOperator as DummyOperator
from airflow.operators.python import PythonOperator
from airflow.utils.email import send_email

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": True,
    "email_on_retry": False,
    "email_on_success": True,
    "email": ["chideraozigbo@gmail.com"],
    "retries": 1,
    "retry_delay": timedelta(seconds=3),
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


def send_custom_email_fn(**kwargs):
    subject = "🟢 DAG Success: simple_addition_dag"
    html_content = """
    <h3>The DAG has run successfully!</h3>
    <p>Everything worked as expected 🎉</p>
    """
    send_email(
        to=["chideraozigbo@gmail.com"],
        subject=subject,
        html_content=html_content,
    )


start = DummyOperator(task_id="start", dag=dag)

addition_task = PythonOperator(
    task_id="addition_task",
    python_callable=perform_addition,
    op_kwargs={"a": 5, "b": 3},
    dag=dag,
)

send_custom_email = PythonOperator(
    task_id="send_custom_email",
    python_callable=send_custom_email_fn,
    provide_context=True,
    dag=dag,
)

end = DummyOperator(task_id="end", dag=dag)

start >> addition_task >> send_custom_email >> end

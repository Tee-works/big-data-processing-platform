import smtplib
import ssl
from email.message import EmailMessage

from airflow.models import Variable


def notification_email(context, state):
    """
    This function send notification of a failed dags task
    """
    dag = context.get("task_instance").dag_id
    task = context.get("task_instance").task_id
    exec_date = context.get("task_instance").start_date
    log = context.get("task_instance").log_url
    dag_owner = context.get("task_instance").owner
    email_receiver = context.get("task_instance").email

    if isinstance(email_receiver, list):
        email_receiver = ", ".join(email_receiver)

    email_sender = Variable.get("email_sender")
    email_password = Variable.get("email_password")
    mail_server = Variable.get("MAIL_SERVER")
    email_port = int(Variable.get("email_port"))

    print(context)
    subject = f"Airflow Alert: Task '{task}' in DAG '{dag}' has {state.upper()}"
    body = f"""
    Hey {dag_owner}

    The task {task} in dag {dag} runninng in Managed Apache Airflow \
        has {state} for run date {exec_date}

    Here is the log url: {log}
    """
    em = EmailMessage()
    em["From"] = email_sender
    em["To"] = email_receiver
    em["Subject"] = subject
    em.set_content(body)

    ssl_context = ssl.create_default_context()

    with smtplib.SMTP_SSL(mail_server, email_port, context=ssl_context) as smtp:
        smtp.login(email_sender, email_password)
        smtp.sendmail(email_sender, email_receiver, em.as_string())
        print("Email Sent Successfully")


def task_state_alert(context):
    """
    This function send notification of a dags task
    """
    state = context.get("task_instance").state
    if state in ("success","failed"):
        notification_email(context, state)

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from airflow.models import Variable


def notification_email(context, state):
    """
    This function send notification of a failed dags task
    """
    task_instance = context.get("task_instance")
    dag = task_instance.dag_id
    task = task_instance.task_id
    exec_date = task_instance.start_date
    log = task_instance.log_url

    # Get the DAG object
    dag_obj = context.get("dag") or task_instance.dag

    # Get owner from DAG's default_args
    dag_owner = "Airflow User"
    if hasattr(dag_obj, "default_args") and "owner" in dag_obj.default_args:
        dag_owner = dag_obj.default_args["owner"]

    # Get email from DAG's default_args
    email_receiver = None
    if hasattr(dag_obj, "default_args") and "email" in dag_obj.default_args:
        email_receiver = dag_obj.default_args["email"]

    # If no email is found, use a default from Variables
    if not email_receiver:
        email_receiver = Variable.get(
            "default_alert_email", "chideraozigbo@gmail.com"
        )

    if isinstance(email_receiver, list):
        email_receiver = ", ".join(email_receiver)

    # Get email configuration from Variables
    email_sender = Variable.get("email_sender")
    email_password = Variable.get("email_password")
    mail_server = Variable.get("MAIL_SERVER")
    email_port = int(Variable.get("email_port"))

    subject = f"Airflow Alert: Task in DAG '{dag}' has {state.upper()}"
    body = f"""
    Hey {dag_owner}

    The task {task} in dag {dag} running in Managed Apache Airflow \
        has {state} for run date {exec_date}

    Here is the log url: {log}
    """
    msg = MIMEMultipart()
    msg['From'] = email_sender
    msg['To'] = email_receiver
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'plain'))

    try:
        with smtplib.SMTP(mail_server, email_port) as server:
            server.starttls()
            server.login(email_sender, email_password)
            server.send_message(msg)
        print("Email sent successfully")
    except Exception as e:
        print(f"Failed to send email: {str(e)}")


def task_state_alert(context):
    """
    This function sends notification of a dags task based on its state
    """
    task_instance = context.get("task_instance")
    if task_instance:
        state = task_instance.state
        if state in ("success", "failed"):
            notification_email(context, state)

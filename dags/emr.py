from datetime import datetime, timedelta

from airflow import DAG
from airflow.models import Variable
from airflow.operators.empty import EmptyOperator as DummyOperator
from airflow.providers.amazon.aws.operators.emr import (
    EmrAddStepsOperator, EmrCreateJobFlowOperator, EmrTerminateJobFlowOperator)
from airflow.providers.amazon.aws.sensors.emr import (EmrJobFlowSensor,
                                                      EmrStepSensor)
from airflow.utils.trigger_rule import TriggerRule
from notification.email import task_state_alert

subnet_id = Variable.get("private_subnet_id")

DEFAULT_ARGS = {
    "owner": "team_4",
    "depends_on_past": False,
    "email": [
        "chideraozigbo@gmail.com",
        "kingsolomonifeanyi@gmail.com",
        "iyanujesuakinyefa@gmail.com",
    ],
    "email_on_failure": True,
    "email_on_retry": False,
    "on_failure_callback": task_state_alert,
    "retries": 1,
    "retry_delay": timedelta(seconds=5),
}

JOB_FLOW_OVERRIDES = {
    "Name": "big-data-emr",
    "ReleaseLabel": "emr-7.8.0",
    "Applications": [{"Name": "Hadoop"}, {"Name": "Spark"}],
    "Instances": {
        "InstanceGroups": [
            {
                "Name": "Master node",
                "Market": "SPOT",
                "InstanceRole": "MASTER",
                "InstanceType": "m5.xlarge",
                "InstanceCount": 1,
            },
            {
                "Name": "Worker nodes",
                "Market": "SPOT",
                "InstanceRole": "CORE",
                "InstanceType": "m5.xlarge",
                "InstanceCount": 2,
            },
        ],
        "KeepJobFlowAliveWhenNoSteps": True,
        "TerminationProtected": False,
        "Ec2KeyName": "cyberdom-key",
        "Ec2SubnetId": subnet_id,
    },
    "VisibleToAllUsers": True,
    "JobFlowRole": "EMR_EC2_DefaultRole",
    "ServiceRole": "EMR_DefaultRole",
    "LogUri": "s3://big-data-bck/logs/emr/",
}

SPARK_STEPS = [
    {
        "Name": "Move raw data from S3",
        "ActionOnFailure": "TERMINATE_CLUSTER",
        "HadoopJarStep": {
            "Jar": "command-runner.jar",
            "Args": [
                "s3-dist-cp",
                "--src=s3://big-data-bck/data",
                "--dest=/movie",
            ],
        },
    },
    {
        "Name": "Run Spark Job",
        "ActionOnFailure": "TERMINATE_CLUSTER",
        "HadoopJarStep": {
            "Jar": "command-runner.jar",
            "Args": [
                "spark-submit",
                "--deploy-mode",
                "client",
                "s3://big-data-bck/etl/pyspark_s3.py",
            ],
        },
    },
    {
        "Name": "Move clean data  to S3",
        "ActionOnFailure": "TERMINATE_CLUSTER",
        "HadoopJarStep": {
            "Jar": "command-runner.jar",
            "Args": [
                "s3-dist-cp",
                "--src=/output",
                "--dest=s3://big-data-bck/output",
            ],
        },
    },
]

with DAG(
    dag_id="big_data_pipeline_DAG",
    description="Managed Apache Airflow orchestrates Spark workflow ",
    default_args=DEFAULT_ARGS,
    start_date=datetime(2025, 4, 14),
    schedule_interval=timedelta(days=1),
    tags=["big_data_pipeline"],
) as dag:

    begin = DummyOperator(task_id="begin_workflow")

    create_cluster = EmrCreateJobFlowOperator(
        task_id="create_emr_cluster",
        job_flow_overrides=JOB_FLOW_OVERRIDES,
        aws_conn_id="aws_default",
        emr_conn_id="emr_default",
    )

    check_cluster_ready = EmrJobFlowSensor(
        task_id="check_cluster_ready",
        job_flow_id=(
            "{{ task_instance.xcom_pull(task_ids='create_emr_cluster', "
            "key='return_value') }}"
        ),
        target_states=["WAITING", "RUNNING"],
        poke_interval=30,
        timeout=1200,
    )

    add_step = EmrAddStepsOperator(
        task_id="submit_spark_application",
        job_flow_id=(
            "{{ task_instance.xcom_pull(task_ids='create_emr_cluster', "
            "key='return_value') }}"
        ),
        aws_conn_id="aws_default",
        steps=SPARK_STEPS,
        wait_for_completion=True,
    )

    check_step = EmrStepSensor(
        task_id="check_submission_status",
        job_flow_id=(
            "{{ task_instance.xcom_pull('create_emr_cluster', "
            "key='return_value') }}"
        ),
        step_id=(
            "{{ task_instance.xcom_pull(task_ids='submit_spark_application', "
            "key='return_value')[0] }}"
        ),
        aws_conn_id="aws_default",
        poke_interval=30,
        timeout=3600,
    )

    remove_cluster = EmrTerminateJobFlowOperator(
        task_id="terminate_emr_cluster",
        job_flow_id=(
            "{{ task_instance.xcom_pull(task_ids='create_emr_cluster',"
            "key='return_value') }}"
        ),
        aws_conn_id="aws_default",
        trigger_rule=TriggerRule.ALL_DONE,
    )

    end = DummyOperator(task_id="end_workflow")

    (
        begin
        >> create_cluster
        >> check_cluster_ready
        >> add_step
        >> check_step
        >> remove_cluster
        >> end
    )

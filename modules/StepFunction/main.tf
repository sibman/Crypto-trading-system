variable project_tag {}
variable backtest1_Arn {}
variable backtest2_Arn {}
variable TopMarketCapUpdate_Arn {}
variable HistoricalDataUpdate_Arn {}
variable instance_id {}

# EventBridge rule to schedule this lambda function
resource "aws_cloudwatch_event_rule" "refresh-schedule" {
    name = "refresh-schedule"
    description = "Trigger step function every n time interval"
    schedule_expression = "rate(7 days)"
    tags = {
        project = var.project_tag
    }
}

resource "aws_cloudwatch_event_target" "CryptoStateMachine" {
    rule = aws_cloudwatch_event_rule.refresh-schedule.name
    arn = aws_sfn_state_machine.CryptoStateMachine.arn
    role_arn = aws_iam_role.EventbridgeSchedulerRole.arn
}

# Step function
resource "aws_sfn_state_machine" "CryptoStateMachine" {
  name     = "CryptoStateMachine"
  role_arn = aws_iam_role.Step-FunctionRole.arn
  tags = {
    project = var.project_tag
  }
  definition = <<EOF
{
  "Comment": "Step function for crypto_trading_system",
  "StartAt": "TopMarketCapUpdate",
  "States": {
    "TopMarketCapUpdate": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${var.TopMarketCapUpdate_Arn}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "HistoricalDataUpdate",
      "ResultSelector": {
        "statusCode.$": "$.SdkHttpMetadata.HttpStatusCode"
      }
    },
    "HistoricalDataUpdate": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${var.HistoricalDataUpdate_Arn}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "CryptoETLJob",
      "ResultSelector": {
        "statusCode.$": "$.SdkHttpMetadata.HttpStatusCode"
      }
    },
    "CryptoETLJob": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startJobRun.sync",
      "Parameters": {
        "JobName": "CryptoETLJob"
      },
      "Next": "Parallel",
      "ResultSelector": {
        "statusCode.$": "$.SdkHttpMetadata.HttpStatusCode"
      }
    },
    "Parallel": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "BacktestingAnalysisUpdate-1",
          "States": {
            "BacktestingAnalysisUpdate-1": {
              "Type": "Task",
              "Resource": "arn:aws:states:::lambda:invoke",
              "Parameters": {
                "Payload.$": "$",
                "FunctionName": "${var.backtest1_Arn}"
              },
              "Retry": [
                {
                  "ErrorEquals": [
                    "Lambda.ServiceException",
                    "Lambda.AWSLambdaException",
                    "Lambda.SdkClientException",
                    "Lambda.TooManyRequestsException"
                  ],
                  "IntervalSeconds": 2,
                  "MaxAttempts": 6,
                  "BackoffRate": 2
                }
              ],
              "ResultSelector": {
                "statusCode.$": "$.SdkHttpMetadata.HttpStatusCode"
              },
              "End": true
            }
          }
        },
        {
          "StartAt": "BacktestingAnalysisUpdate-2",
          "States": {
            "BacktestingAnalysisUpdate-2": {
              "Type": "Task",
              "Resource": "arn:aws:states:::lambda:invoke",
              "Parameters": {
                "Payload.$": "$",
                "FunctionName": "${var.backtest2_Arn}"
              },
              "Retry": [
                {
                  "ErrorEquals": [
                    "Lambda.ServiceException",
                    "Lambda.AWSLambdaException",
                    "Lambda.SdkClientException",
                    "Lambda.TooManyRequestsException"
                  ],
                  "IntervalSeconds": 2,
                  "MaxAttempts": 6,
                  "BackoffRate": 2
                }
              ],
              "ResultSelector": {
                "statusCode.$": "$.SdkHttpMetadata.HttpStatusCode"
              },
                  "End": true
                }
              }
            }
          ],
          "Next": "RebootInstances"
        },
          "RebootInstances": {
            "Type": "Task",
            "End": true,
            "Parameters": {
              "InstanceIds": [
                "${var.instance_id}"
              ]
            },
            "Resource": "arn:aws:states:::aws-sdk:ec2:rebootInstances"
    }
  },
  "TimeoutSeconds": 1600
}
EOF
}


# IAM role for step function
resource "aws_iam_role" "Step-FunctionRole" {
    name = "Step-FunctionRole"
    assume_role_policy = <<EOF
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "states.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }
        EOF
    tags = {
        project = var.project_tag
    }
}



resource "aws_iam_policy" "Step-FunctionPolicy" {
    name = "Step-FunctionPolicy"
    description = "An additional policy for Step-Function flow"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
              "lambda:InvokeFunction",
              "xray:PutTraceSegments",
              "xray:PutTelemetryRecords",
              "xray:GetSamplingRules",
              "xray:GetSamplingTargets",
              "ec2:RebootInstances",
              "ec2:StartInstances",
              "ec2:StopInstances",
              "glue:StartJobRun",
              "glue:GetJobRun",
              "glue:GetJobRuns",
              "glue:BatchStopJobRun"
            ],
            "Resource": "*"
        }
    ]
}
EOF
    tags = {
        project = var.project_tag
    }
}

resource "aws_iam_role_policy_attachment" "attach_1" {
  role       = aws_iam_role.Step-FunctionRole.name
  policy_arn = aws_iam_policy.Step-FunctionPolicy.arn
}

# IAM role for eventbridge
resource "aws_iam_role" "EventbridgeSchedulerRole" {
    name = "EventbridgeSchedulerRole"
    assume_role_policy = <<EOF
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "scheduler.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }
        EOF
    tags = {
        project = var.project_tag
    }
}



resource "aws_iam_policy" "EventbridgeSchedulerPolicy" {
    name = "EventbridgeSchedulerPolicy"
    description = "An additional policy for Eventbridge Scheduler"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "states:StartExecution"
            ],
            "Resource": "*"
        }
    ]
}
EOF
    tags = {
        project = var.project_tag
    }
}

resource "aws_iam_role_policy_attachment" "attach_2" {
  role       = aws_iam_role.EventbridgeSchedulerRole.name
  policy_arn = aws_iam_policy.EventbridgeSchedulerPolicy.arn
}

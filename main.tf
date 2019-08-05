locals {
  defaults = {
    additional_iam_policies = []
    stage = {
      action = {
        category         = null
        owner            = null
        name             = null
        provider         = null
        version          = null
        configuration    = null
        input_artifacts  = null
        output_artifacts = null
        role_arn         = null
        run_order        = null
      }
    }
  }
}


resource "aws_codepipeline" "main" {
  count = length(var.pipelines)

  name     = var.pipelines[count.index].name
  role_arn = aws_iam_role.main[count.index].arn

  artifact_store {
    location = "${aws_s3_bucket.main.bucket}"
    type     = "S3"
  }

  dynamic "stage" {
    for_each = var.pipelines[count.index].stages
    content {
      name = lookup(stage.value, "name")
      action {
        name             = lookup(stage.value.action, "name", lookup(local.defaults.stage.action, "name"))
        category         = lookup(stage.value.action, "category", lookup(local.defaults.stage.action, "category"))
        owner            = lookup(stage.value.action, "owner", lookup(local.defaults.stage.action, "owner"))
        provider         = lookup(stage.value.action, "provider", lookup(local.defaults.stage.action, "provider"))
        version          = lookup(stage.value.action, "version", lookup(local.defaults.stage.action, "version"))
        configuration    = lookup(stage.value.action, "configuration", lookup(local.defaults.stage.action, "configuration"))
        input_artifacts  = lookup(stage.value.action, "input_artifacts", lookup(local.defaults.stage.action, "input_artifacts"))
        output_artifacts = lookup(stage.value.action, "output_artifacts", lookup(local.defaults.stage.action, "output_artifacts"))
        role_arn         = lookup(stage.value.action, "role_arn", lookup(local.defaults.stage.action, "role_arn"))
        run_order        = lookup(stage.value.action, "run_order", lookup(local.defaults.stage.action, "run_order"))
      }
    }
  }
}



resource "aws_s3_bucket" "main" {
  bucket = "${var.name}"
}


resource "aws_iam_role" "main" {
  count = length(var.pipelines)

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["codepipeline.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "main" {
  count = length(var.pipelines)

  role   = aws_iam_role.main[count.index].name
  policy = "${data.aws_iam_policy_document.main[count.index].json}"
}

data "aws_iam_policy_document" "main" {
  count = length(var.pipelines[*])

  statement {
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.main.bucket}",
    ]
  }

  statement {
    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.main.bucket}/${var.pipelines[count.index].name}",
      "arn:aws:s3:::${aws_s3_bucket.main.bucket}/${var.pipelines[count.index].name}/*",
    ]
  }

  dynamic "statement" {
    for_each = lookup(var.pipelines[count.index], "additional_iam_policies", lookup(local.defaults, "additional_iam_policies"))
    content {
      actions   = lookup(statement.value, "actions")
      resources = lookup(statement.value, "resources")
    }
  }
}

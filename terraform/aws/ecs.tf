resource "aws_ecs_cluster" "tsujiura" {
  # checkov:skip=CKV_AWS_65:Container Insights costs more than this project can spend
  name = "tsujiura"

  tags = local.common_tags
}

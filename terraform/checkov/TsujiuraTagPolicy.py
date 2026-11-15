from typing import Any

from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


class TsujiuraTagPolicy(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="Ensure Project=Tsujiura tag is present on AWS resources",
            id="CKV_TSUJIURA_1",
            categories=[CheckCategories.CONVENTION],
            supported_resources=["*"],
        )

    def scan_resource_conf(self, conf: dict[str, list[Any]]) -> CheckResult:
        if not getattr(self, "entity_type", "").startswith("aws_"):
            return CheckResult.PASSED
        tags = conf.get("tags", [{}])
        if isinstance(tags, list):
            tags = tags[0] if tags else {}
        if not isinstance(tags, dict):
            return CheckResult.UNKNOWN
        project_value = tags.get("Project", "")
        if isinstance(project_value, list) and project_value:
            project_value = project_value[0]
        if project_value == "Tsujiura":
            return CheckResult.PASSED
        return CheckResult.FAILED


check = TsujiuraTagPolicy()

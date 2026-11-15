from typing import Any

from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


class TsujiuraLabelPolicy(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="Ensure project=tsujiura label is present on Google Cloud resources",
            id="CKV_TSUJIURA_2",
            categories=[CheckCategories.CONVENTION],
            supported_resources=["*"],
        )

    def scan_resource_conf(self, conf: dict[str, list[Any]]) -> CheckResult:
        if not getattr(self, "entity_type", "").startswith("google_"):
            return CheckResult.PASSED
        # Notification channels use labels for channel settings and take resource labels as user_labels.
        labels = conf.get("user_labels") or conf.get("labels") or [{}]
        if isinstance(labels, list):
            labels = labels[0] if labels else {}
        if not isinstance(labels, dict):
            return CheckResult.UNKNOWN
        project_value = labels.get("project", "")
        if isinstance(project_value, list) and project_value:
            project_value = project_value[0]
        if project_value == "tsujiura":
            return CheckResult.PASSED
        return CheckResult.FAILED


check = TsujiuraLabelPolicy()

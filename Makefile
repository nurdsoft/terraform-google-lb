# -----------------------------------------------------------------------------
# Make targets to provide a consistent user experience when running Terraform.
# -----------------------------------------------------------------------------

# Static variables.
TF_PLAN_FILEPATH=plan.tfplan
TF_VARS_FILE=examples.tfvars

# Dynamic variables
TF_WORKDIR?=examples
# Options: minimal, complete
SVC?= complete

define DEFAULT_PLAN_ARGS
-no-color -input=false \
-var-file=${TF_VARS_FILE} \
-out=${TF_PLAN_FILEPATH} \
${DEFAULT_ARGS}
endef

define DEFAULT_APPLY_ARGS
--auto-approve -input=false \
-var-file=${TF_VARS_FILE} \
${DEFAULT_ARGS}
endef

define DEFAULT_DESTROY_ARGS
-auto-approve \
-var-file=${TF_VARS_FILE} \
${DEFAULT_ARGS}
endef

# Avoid name collisions between targets and files.
.PHONY: help fmt init validate plan apply plan-destroy destroy clean docs

# A target to format and present all supported targets with their descriptions.
help: Makefile
	@sed -n 's/^##//p' $<

## fmt          : Run terraform fmt.
fmt:
	terraform -chdir=${TF_WORKDIR}/${SVC} fmt -check=true -diff

## init         : Run terraform init.
init:
	terraform -chdir=${TF_WORKDIR}/${SVC} init

## validate     : Run terraform validate.
validate:
	terraform -chdir=${TF_WORKDIR}/${SVC} validate -no-color

## plan         : Run terraform plan for the provided service.
plan: clean fmt init validate
	terraform -chdir=${TF_WORKDIR}/${SVC} plan ${DEFAULT_PLAN_ARGS} -input=false

## apply        : Run terraform apply for the provided service.
apply:
	terraform -chdir=${TF_WORKDIR}/${SVC} apply ${DEFAULT_APPLY_ARGS}

## plan-destroy : Run terraform plan destroy for the provided service.
plan-destroy: clean
	terraform -chdir=${TF_WORKDIR}/${SVC} plan -destroy -no-color ${DEFAULT_PLAN_ARGS} -input=false

## destroy      : Run terraform destroy for the provided service.
destroy:
	terraform -chdir=${TF_WORKDIR}/${SVC} destroy ${DEFAULT_DESTROY_ARGS}

## clean        : Find and remove all the temporary files
clean:
	@find . -name ".terraform" -type d -print0 | xargs -0 -I {} rm -rf "{}"
	@find . -name ".terraform.lock.hcl" -type f -print0 | xargs -0 -I {} rm -rf "{}"
	@find . -name "plan.tfplan" -type f -print0 | xargs -0 -I {} rm -rf "{}"
	@rm -f ${TF_STATE_FILEPATH}

## docs 	      : Generate documentation for the module.
docs:
	@terraform-docs markdown .

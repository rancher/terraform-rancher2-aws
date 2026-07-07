# Update Test Suite

We want to automatically update as much as possible in a GitHub workflow that generates a PR.
If we find updates that the workflow can't resolve it should error.

Create ./.github/workflows/update-go-deps.yaml and update-go-deps.sh to facilitate this.

We have been working on update-go-deps.sh. which is failing because the aws-sdk-go to aws-sdk-go-v2 migration requires significant rework. We will upgrade the package manually by using t.Context() for any contexts that need to be added and indirecting any variables that need it.

I want you to check your context % and stop if your context % is greater than 40%. I want you to report that the context window is 40% full and give a summary of what you are working on, accomplished, and what next steps should be.

* Find and update all deprecated functions.
  * `random.UniqueId()` to `random.UniqueID()`
  * `git.GetRepoRoot(t)` to `git.GetRepoRootContext(t, t.Context(), "")`
  * `map[string]interface{}` to `map[string]any`
  * `terraform.InitE(t, terraformOptions)` to `terraform.InitContextE(t, t.Context(), terraformOptions)`
  * `terraform.DestroyE(t, terraformOptions)` to `terraform.DestroyContextE(t, t.Context(), terraformOptions)`
  * `terraform.InitAndPlan(t, terraformOptions)` to `terraform.InitAndPlanContext(t, t.Context(), terraformOptions)`
  * `terraform.InitAndApply(t, terraformOptions)` to `terraform.InitAndApplyContext(t, t.Context(), terraformOptions)`
  * `terraform.InitAndApplyE(t, ` to `terraform.InitAndApplyContextE(t, t.Context(), `
  * `terraform.OutputAll(t, terraformOptions)` to `terraform.OutputAllContext(t, t.Context(), terraformOptions)`
  * `terraform.OutputMap(t, ` to `terraform.OutputMapContext(t, t.Context(), `
  * `terraform.OutputJson(t, ` to `terraform.OutputJSONContext(t, t.Context(), `
  * `terraform.OutputString(t, ` to `terraform.OutputStringContext(t, t.Context(), `
  * `terraform.OutputBool(t, ` to `terraform.OutputBoolContext(t, t.Context(), `
  * `terraform.OutputInt(t, ` to `terraform.OutputIntContext(t, t.Context(), `
  * `terraform.OutputFloat(t, ` to `terraform.OutputFloatContext(t, t.Context(), `
  * `terraform.OutputList(t, ` to `terraform.OutputListContext(t, t.Context(), `
  * `aws.DeleteEC2KeyPair(t, keyPair)` to `aws.DeleteEC2KeyPairContext(t, t.Context(), keyPair)`
  * `aws.CreateAndImportEC2KeyPair(t, region, keyPairName)` to `aws.CreateAndImportEC2KeyPairContext(t, t.Context(), region, keyPairName)`
  * `aws.NewEc2ClientE(t, region)` to `aws.NewEc2ClientContextE(t, t.Context(), region)`
  * `aws.AddTagsToResource(t, ` to `aws.AddTagsToResourceContext(t, t.Context(), `
  * `aws.AddTagsToResourceE(t, ` to `aws.AddTagsToResourceContextE(t, t.Context(), `
  * `ssh.SshAgentWithKeyPair(t, keyPair.KeyPair)` to `ssh.SSHAgentWithKeyPair(t, t.Context(), keyPair.KeyPair)`
  * `ssh.CheckSshCommand(t, host` to `ssh.CheckSSHCommandContext(t, t.Context(), &host`
  * `ssh.SshAgent` to `ssh.SSHAgent`

The git package is scheduled for removal in Terratest v2.
Each helper wraps a single git command (for example, git rev-parse or git describe).
There is no public replacement; the package is being dropped.
To replace, write scripts to the test/scripts directory and execute them with shell.Command, this allows us to run shellcheck on them.

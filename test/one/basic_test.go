package one

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/rancher/terraform-rancher2-aws/test/fixture"
)

func TestOneBasic(t *testing.T) {
	t.Parallel()
	f := fixture.NewFixture(t, "one")
	defer f.Teardown(t)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: f.ExampleDir,
		// Variables to pass to our Terraform code using -var options
		Vars: map[string]any{
			"identifier":      f.ID,
			"owner":           f.Owner,
			"key_name":        f.KeyPair.Name,
			"key":             f.KeyPair.PublicKey,
			"zone":            os.Getenv("ZONE"),
			"rke2_version":    f.Rke2Version,
			"rancher_version": f.RancherVersion,
			"file_path":       f.TestDir,
			"acme_server_url": f.AcmeServerURL,
		},
		// Environment variables to set when running Terraform
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":  f.Region,
			"AWS_REGION":          f.Region,
			"TF_DATA_DIR":         f.TestDir,
			"TF_PLUGIN_CACHE_DIR": f.PluginsDir,
			"TF_IN_AUTOMATION":    "1",
			"TF_CLI_ARGS_plan":    "-no-color -state=" + f.TestDir + "/tfstate",
			"TF_CLI_ARGS_apply":   "-no-color -state=" + f.TestDir + "/tfstate -parallelism=5",
			"TF_CLI_ARGS_destroy": "-no-color -state=" + f.TestDir + "/tfstate",
			"TF_CLI_ARGS_output":  "-no-color -state=" + f.TestDir + "/tfstate",
		},
		RetryableTerraformErrors: fixture.GetRetryableTerraformErrors(),
		NoColor:                  true,
		SshAgent:                 f.SSHAgent,
		Upgrade:                  true,
	})

	f.TeardownOptions = append(f.TeardownOptions, terraformOptions)

	kubeconfigPath := filepath.Join(f.TestDir, "kubeconfig")
	_, err := terraform.InitAndApplyContextE(t, t.Context(), terraformOptions)
	if err != nil {
		t.Log("Test failed, tearing down...")
		fixture.GetErrorLogs(t, kubeconfigPath)
		t.Fatalf("Error creating cluster: %v", err)
	}
	fixture.CheckReady(t, kubeconfigPath)
	fixture.CheckRunning(t, kubeconfigPath)
	if t.Failed() {
		t.Log("Test failed...")
	} else {
		t.Log("Test passed...")
	}
}

package test

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/google/go-github/v53/github"
	aws "github.com/gruntwork-io/terratest/modules/aws"
	g "github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBasic(t *testing.T) {
	t.Parallel()
	id := getId()
	region := getRegion()
	directory := "basic"
	owner := "terraform-ci@suse.com"
	setAcmeServer()

	repoRoot, err := filepath.Abs(g.GetRepoRoot(t))
	require.NoError(t, err)

	err = createTestDirectories(t, id)
	require.NoError(t, err)
	exampleDir := repoRoot + "/examples/" + directory
	dataDir := repoRoot + "/tests/data/" + id
	installDir := repoRoot + "/tests/data/" + id + "/install"
	testDir := repoRoot + "/tests/data/" + id + "/test"

	keyPair, err := createKeypair(t, region, owner, id)
	require.NoError(t, err)
	sshAgent := ssh.SshAgentWithKeyPair(t, keyPair.KeyPair)
	defer sshAgent.Stop()
	t.Logf("Key %s created and added to agent", keyPair.Name)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: exampleDir,
		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"key_name":     keyPair.Name,
			"key":          keyPair.KeyPair.PublicKey,
			"identifier":   id,
			"owner":        owner,
			"zone":         os.Getenv("ZONE"),
			"rke2_version": getLatestRelease(t, "rancher", "rke2"),
			"file_path":    installDir,
		},
		// Environment variables to set when running Terraform
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":  region,
			"AWS_REGION":          region,
			"TF_DATA_DIR":         testDir,
			"TF_IN_AUTOMATION":    "1",
			"TF_CLI_ARGS_plan":    "-state=" + testDir + "/tfstate",
			"TF_CLI_ARGS_apply":   "-state=" + testDir + "/tfstate",
			"TF_CLI_ARGS_destroy": "-state=" + testDir + "/tfstate",
			"TF_CLI_ARGS_output":  "-state=" + testDir + "/tfstate",
		},
		RetryableTerraformErrors: getRetryableTerraformErrors(),
		NoColor:                  true,
		SshAgent:                 sshAgent,
		Upgrade:                  true,
	})
	defer teardown(t, dataDir, keyPair)
	defer terraform.Destroy(t, terraformOptions)
	_, err = terraform.InitAndApplyE(t, terraformOptions)
	if err != nil {
		terraform.Destroy(t, terraformOptions)
		teardown(t, dataDir, keyPair)
		t.Fatalf("Error creating cluster: %s", err)
	}
	output := terraform.OutputJson(t, terraformOptions, "")
	type OutputData struct {
		Kubeconfig struct {
			Sensitive bool   `json:"sensitive"`
			Type      string `json:"type"`
			Value     string `json:"value"`
		} `json:"kubeconfig"`
	}
	var data OutputData
	err = json.Unmarshal([]byte(output), &data)
	if err != nil {
		terraform.Destroy(t, terraformOptions)
		teardown(t, dataDir, keyPair)
		t.Fatalf("Error unmarshalling Json: %v", err)
	}
	kubeconfig := data.Kubeconfig.Value
	assert.NotEmpty(t, kubeconfig)
	if kubeconfig == "{}" {
		terraform.Destroy(t, terraformOptions)
		teardown(t, dataDir, keyPair)
		t.Fatal("Kubeconfig not found")
	}
	kubeconfigPath := dataDir + "/kubeconfig"
	os.WriteFile(kubeconfigPath, []byte(kubeconfig), 0644)
	basicCheckReady(t, kubeconfigPath)
}

func basicCheckReady(t *testing.T, kubeconfigPath string) {
	script, err2 := os.ReadFile("./scripts/readyNodes.sh")
	if err2 != nil {
		require.NoError(t, err2)
	}
	readyScript := shell.Command{
		Command: "bash",
		Args:    []string{"-c", string(script)},
		Env: map[string]string{
			"KUBECONFIG": kubeconfigPath,
		},
	}
	out := shell.RunCommandAndGetOutput(t, readyScript) // if the script fails, it will fail the test
	t.Logf("Ready script output: %s", out)
}

func createKeypair(t *testing.T, region string, owner string, id string) (*aws.Ec2Keypair, error) {
	t.Log("Creating keypair...")
	// Create an EC2 KeyPair that we can use for SSH access
	keyPairName := fmt.Sprintf("terraform-ci-%s", id)
	keyPair := aws.CreateAndImportEC2KeyPair(t, region, keyPairName)

	// tag the key pair so we can find in the access module
	client, err := aws.NewEc2ClientE(t, region)
	require.NoError(t, err)
	if err != nil {
		return nil, err
	}

	k := "key-name"
	keyNameFilter := ec2.Filter{
		Name:   &k,
		Values: []*string{&keyPairName},
	}
	input := &ec2.DescribeKeyPairsInput{
		Filters: []*ec2.Filter{&keyNameFilter},
	}
	result, err := client.DescribeKeyPairs(input)
	require.NoError(t, err)
	require.NotEmpty(t, result.KeyPairs)
	if err != nil {
		return nil, err
	}

	err = aws.AddTagsToResourceE(t, region, *result.KeyPairs[0].KeyPairId, map[string]string{"Name": keyPairName, "Owner": owner})
	require.NoError(t, err)
	if err != nil {
		return nil, err
	}

	// Verify that the name and owner tags were placed properly
	k = "tag:Name"
	keyNameFilter = ec2.Filter{
		Name:   &k,
		Values: []*string{&keyPairName},
	}
	input = &ec2.DescribeKeyPairsInput{
		Filters: []*ec2.Filter{&keyNameFilter},
	}
	result, err = client.DescribeKeyPairs(input)
	require.NoError(t, err)
	require.NotEmpty(t, result.KeyPairs)
	if err != nil {
		return nil, err
	}

	k = "tag:Owner"
	keyNameFilter = ec2.Filter{
		Name:   &k,
		Values: []*string{&owner},
	}
	input = &ec2.DescribeKeyPairsInput{
		Filters: []*ec2.Filter{&keyNameFilter},
	}
	result, err = client.DescribeKeyPairs(input)
	require.NoError(t, err)
	require.NotEmpty(t, result.KeyPairs)
	if err != nil {
		return nil, err
	}
	return keyPair, nil
}

func getRetryableTerraformErrors() map[string]string {
	retryableTerraformErrors := map[string]string{
		// The reason is unknown, but eventually these succeed after a few retries.
		".*unable to verify signature.*":                    "Failed due to transient network error.",
		".*unable to verify checksum.*":                     "Failed due to transient network error.",
		".*no provider exists with the given name.*":        "Failed due to transient network error.",
		".*registry service is unreachable.*":               "Failed due to transient network error.",
		".*connection reset by peer.*":                      "Failed due to transient network error.",
		".*TLS handshake timeout.*":                         "Failed due to transient network error.",
		".*Error: disassociating EC2 EIP.*does not exist.*": "Failed to delete EIP because interface is already gone",
	}
	return retryableTerraformErrors
}

func getLatestRelease(t *testing.T, owner string, repo string) string {
	ghClient := github.NewClient(nil)
	release, _, err := ghClient.Repositories.GetLatestRelease(context.Background(), owner, repo)
	require.NoError(t, err)
	version := *release.TagName
	return version
}

func setAcmeServer() string {
	acmeserver := os.Getenv("ACME_SERVER_URL")
	if acmeserver == "" {
		os.Setenv("ACME_SERVER_URL", "https://acme-staging-v02.api.letsencrypt.org/directory")
	}
	return acmeserver
}

func getRegion() string {
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = os.Getenv("AWS_DEFAULT_REGION")
	}
	if region == "" {
		region = "us-west-2"
	}
	return region
}

func getId() string {
	id := os.Getenv("IDENTIFIER")
	if id == "" {
		id = random.UniqueId()
	}
	id += "-" + random.UniqueId()
	return id
}

func createTestDirectories(t *testing.T, id string) error {
	gwd := g.GetRepoRoot(t)
	fwd, err := filepath.Abs(gwd)
	if err != nil {
		return err
	}
	tdd := fwd + "/tests/data"
	err = os.Mkdir(tdd, 0755)
	if err != nil && !os.IsExist(err) {
		return err
	}
	tdd = fwd + "/tests/data/" + id
	err = os.Mkdir(tdd, 0755)
	if err != nil && !os.IsExist(err) {
		return err
	}
	tdd = fwd + "/tests/data/" + id + "/test"
	err = os.Mkdir(tdd, 0755)
	if err != nil && !os.IsExist(err) {
		return err
	}
	tdd = fwd + "/tests/data/" + id + "/install"
	err = os.Mkdir(tdd, 0755)
	if err != nil && !os.IsExist(err) {
		return err
	}
	return nil
}

func teardown(t *testing.T, directory string, keyPair *aws.Ec2Keypair) {
	err := os.RemoveAll(directory)
	require.NoError(t, err)
	aws.DeleteEC2KeyPair(t, keyPair)
}

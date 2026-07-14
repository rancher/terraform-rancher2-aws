// Package fixture provides testing fixtures and helper functions.
package fixture

import (
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	ec2 "github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/google/go-github/v53/github"
	aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/rancher/terraform-rancher2-aws/test"
	"golang.org/x/oauth2"
)

// GetRancherReleases retrieves the available Rancher releases from GitHub.
func GetRancherReleases(ctx context.Context) (string, string, string, error) {
	releases, err := getReleases(ctx, "rancher", "rancher")
	if err != nil {
		return "", "", "", fmt.Errorf("getting rancher releases: %w", err)
	}
	filterPrerelease(&releases)
	filterPrimeOnly(&releases)
	versions := getVersionsFromReleases(&releases)
	if len(versions) == 0 {
		return "", "", "", errors.New("no eligible versions found")
	}
	zeroPadVersionNumbers(&versions)
	sortVersions(&versions)
	filterDuplicatePatches(&versions)
	getStablePatches(&versions)
	removeZeroPadding(&versions)
	latest := versions[0]
	stable := latest
	lts := stable
	if len(versions) > 1 {
		stable = versions[1]
	}
	if len(versions) > 2 {
		lts = versions[2]
	}
	return latest, stable, lts, nil
}

// GetRke2Releases retrieves the available RKE2 releases from GitHub.
func GetRke2Releases(ctx context.Context) (string, string, string, error) {
	releases, err := getReleases(ctx, "rancher", "rke2")
	if err != nil {
		return "", "", "", fmt.Errorf("getting rke2 releases: %w", err)
	}
	filterPrerelease(&releases)
	versions := getVersionsFromReleases(&releases)
	if len(versions) == 0 {
		return "", "", "", errors.New("no eligible versions found")
	}
	zeroPadVersionNumbers(&versions)
	sortVersions(&versions)
	filterDuplicatePatches(&versions)
	getStablePatches(&versions)
	removeZeroPadding(&versions)
	latest := versions[0]
	stable := latest
	lts := stable
	if len(versions) > 1 {
		stable = versions[1]
	}
	if len(versions) > 2 {
		lts = versions[2]
	}
	return latest, stable, lts, nil
}

func getReleases(ctx context.Context, org string, repo string) ([]*github.RepositoryRelease, error) {
	githubToken := os.Getenv("GITHUB_TOKEN")
	if githubToken == "" {
		fmt.Println("GITHUB_TOKEN environment variable not set")
		return nil, errors.New("GITHUB_TOKEN environment variable not set")
	}

	// Create a new OAuth2 token using the GitHub token
	tokenSource := oauth2.StaticTokenSource(&oauth2.Token{AccessToken: githubToken})
	tokenClient := oauth2.NewClient(ctx, tokenSource)

	// Create a new GitHub client using the authenticated HTTP client
	client := github.NewClient(tokenClient)

	var releases []*github.RepositoryRelease
	releases, _, err := client.Repositories.ListReleases(ctx, org, repo, &github.ListOptions{})
	if err != nil {
		return nil, fmt.Errorf("listing repository releases: %w", err)
	}

	return releases, nil
}

func filterPrimeOnly(r *[]*github.RepositoryRelease) {
	var fr []*github.RepositoryRelease
	releases := *r
	for i := 0; i < len(releases); i++ {
		if len(releases[i].Assets) > 2 { // source zip and tar are always there
			// prime only releases won't have artifacts
			// so we only add releases with more than 2 artifacts
			fr = append(fr, releases[i])
		}
	}
	*r = fr
}

// This effectively removes release candidates as well as pending releases.
func filterPrerelease(r *[]*github.RepositoryRelease) {
	var fr []*github.RepositoryRelease
	releases := *r
	for i := 0; i < len(releases); i++ {
		if !releases[i].GetPrerelease() {
			fr = append(fr, releases[i])
		}
	}
	*r = fr
}

func getVersionsFromReleases(r *[]*github.RepositoryRelease) []string {
	var versions []string
	releases := *r
	for i := 0; i < len(releases); i++ {
		versions = append(versions, *releases[i].TagName)
	}
	return versions
	// [
	//   "v1.28.14+rke2r1",
	//   "v1.30.1+rke2r3",
	//   "v1.29.4+rke2r1",
	//   "v1.30.1+rke2r2",
	//   "v1.29.5+rke2r2",
	//   "v1.30.1+rke2r1",
	//   "v1.27.20+rke2r1",
	//   "v1.30.0+rke2r1",
	//   "v1.29.5+rke2r1",
	//   "v1.28.17+rke2r1",
	//   "v1.4.1+rke2r3",
	//   "v1.28.16+rke2r1",
	//   "v1.28.15+rke2r1",
	// ]
}
func zeroPadVersionNumbers(v *[]string) {
	var zv []string
	versions := *v
	for i := 0; i < len(versions); i++ {
		vp := strings.Split(versions[i], "+") // ["v1.3.1","rke2r3"] OR ["v2.5.4"] if no "+"
		vpp := strings.Split(vp[0], ".")      // ["v1","3","1]
		major := vpp[0]                       // assumes single digit major
		minor := ""
		trivial := ""
		if len(vpp[1]) < 2 {
			minor = fmt.Sprintf("0%s", vpp[1]) // assumes double digit versions
		} else {
			minor = vpp[1]
		}
		if len(vpp[2]) < 2 {
			trivial = fmt.Sprintf("0%s", vpp[2]) // assumes double digit versions
		} else {
			trivial = vpp[2]
		}
		if len(vp) > 1 {
			version := fmt.Sprintf("%s.%s.%s+%s", major, minor, trivial, vp[1]) // "v1.03.01+rke2r3"
			zv = append(zv, version)
		} else {
			version := fmt.Sprintf("%s.%s.%s", major, minor, trivial) // "v1.03.01"
			zv = append(zv, version)
		}
	}
	*v = zv
	// [
	//   "v1.28.14+rke2r1",
	//   "v1.30.01+rke2r3",
	//   "v1.29.04+rke2r1",
	//   "v1.30.01+rke2r2",
	//   "v1.29.05+rke2r2",
	//   "v1.30.01+rke2r1",
	//   "v1.27.20+rke2r1",
	//   "v1.30.00+rke2r1",
	//   "v1.29.05+rke2r1",
	//   "v1.28.17+rke2r1",
	//   "v1.04.01+rke2r3",
	//   "v1.28.16+rke2r1",
	//   "v1.28.15+rke2r1",
	// ]
}

func sortVersions(v *[]string) { // assumes versions are 0 padded already
	slices.SortFunc(*v, func(a, b string) int {
		return cmp.Compare(b, a)
		// [
		//   v1.30.01+rke2r3,
		//   v1.30.01+rke2r2,
		//   v1.30.01+rke2r1,
		//   v1.30.00+rke2r1,
		//   v1.29.05+rke2r2,
		//   v1.29.05+rke2r1,
		//   v1.29.04+rke2r1,
		//   v1.28.17+rke2r1,
		//   v1.28.16+rke2r1,
		//   v1.28.15+rke2r1,
		//   v1.28.14+rke2r1,
		//   v1.27.20+rke2r1,
		//   v1.04.01+rke2r3,
		// ]
	})
}
func filterDuplicatePatches(v *[]string) { // assumes versions are sorted already
	var fv []string
	versions := *v
	fv = append(fv, versions[0])
	for i := 1; i < len(versions); i++ {
		c := versions[i]                // this is all testing if c should be added
		p := versions[i-1]              // p should be greater because the index is smaller
		cp := strings.Split(c[1:], "+") // ["1.30.01","rke2r2"] (c eliminated) // ["1.30.01", "rke2r1"]
		pp := strings.Split(p[1:], "+") // ["1.30.01","rke2r3"]                // ["1.30.00", "rke2r1"]
		if cp[0] != pp[0] {             // if c doesn't share the same version as p
			cpp := strings.Split(cp[0], ".") // ["1","30","00"]
			ppp := strings.Split(pp[0], ".") // ["1","30","01"]
			if cpp[2] != ppp[2] {            // if c doesn't share the same patch as p add it
				fv = append(fv, c)
				// [
				//   v1.30.01+rke2r3,
				//   v1.30.00+rke2r1,
				//   v1.29.05+rke2r2,
				//   v1.29.04+rke2r1,
				//   v1.28.17+rke2r1,
				//   v1.28.16+rke2r1,
				//   v1.28.15+rke2r1,
				//   v1.28.14+rke2r1,
				//   v1.27.20+rke2r1,
				//   v1.04.01+rke2r3,
				// ]
			}
		}
	}
	*v = fv
}

func getStablePatches(v *[]string) { // assumes versions are sorted already
	var fv []string
	versions := *v
	if len(versions) == 0 {
		return
	}

	// Group versions by major.minor
	groupedVersions := make(map[string][]string)
	for _, version := range versions {
		parts := strings.Split(strings.Split(version[1:], "+")[0], ".") // ["v1", "30", "01"]
		majorMinor := fmt.Sprintf("%s.%s", parts[0], parts[1])          // "v1.30"
		groupedVersions[majorMinor] = append(groupedVersions[majorMinor], version)
		// {
		//     "v1.30" = ["v1.30.01+rke2r3", "v1.30.00+rke2r1"]
		//     "v1.29" = ["v1.29.05+rke2r2", "v1.29.04+rke2r1"]
		//     "v1.04" = ["v1.04.01+rke2r3"]
		//     "v1.27" = ["v1.27.20+rke2r1"]
		//     "v1.28" = ["v1.28.17+rke2r1", "v1.28.16+rke2r1", "v1.28.15+rke2r1", "v1.28.14+rke2r1"]
		// }
	}

	// For each group, get the second latest if available, otherwise the latest.
	for _, group := range groupedVersions {
		if len(group) > 1 {
			fv = append(fv, group[1]) // second latest
		} else if len(group) == 1 {
			fv = append(fv, group[0]) // latest (as fallback)
		}
	}
	*v = fv
	// The order is not guaranteed from a map, so we need to sort again.
	sortVersions(v)
	// Expected output:
	// [v1.30.00+rke2r1, v1.29.04+rke2r1, v1.28.16+rke2r1, v1.27.20+rke2r1, v1.04.01+rke2r3]
}

func removeZeroPadding(v *[]string) {
	var zv []string
	versions := *v
	for i := 0; i < len(versions); i++ {
		vp := strings.Split(versions[i], "+") // ["v1.03.01","rke2r3"] OR ["v2.05.04"] if no "+"
		vpp := strings.Split(vp[0], ".")      // ["v1","03","01]
		major := vpp[0]                       // assumes single digit major
		minor := vpp[1]
		trivial := vpp[2]
		if minor[0] == '0' {
			minor = minor[1:]
		}
		if trivial[0] == '0' {
			trivial = trivial[1:]
		}
		if len(vp) > 1 {
			version := fmt.Sprintf("%s.%s.%s+%s", major, minor, trivial, vp[1]) // "v1.3.1+rke2r3"
			zv = append(zv, version)
		} else {
			version := fmt.Sprintf("%s.%s.%s", major, minor, trivial) // "v1.3.1"
			zv = append(zv, version)
		}
	}
	*v = zv
	// [
	//   v1.30.0+rke2r1,
	//   v1.29.4+rke2r1,
	//   v1.28.16+rke2r1,
	//   v1.27.20+rke2r1,
	//   v1.4.1+rke2r3,
	// ]
}

// CreateKeypair generates a new EC2 key pair for testing and tags it appropriately.
func CreateKeypair(ctx context.Context, t *testing.T, region string, owner string, id string) (*aws.Ec2Keypair, error) {
	t.Log("Creating keypair...")
	// Create an EC2 KeyPair that we can use for SSH access
	keyPairName := id
	keyPair := aws.CreateAndImportEC2KeyPairContext(t, ctx, region, keyPairName)

	// tag the key pair so we can find in the access module
	client, err := aws.NewEc2ClientContextE(t, ctx, region)
	if err != nil {
		return nil, fmt.Errorf("creating ec2 client: %w", err)
	}

	k := "key-name"
	keyNameFilter := ec2types.Filter{
		Name:   &k,
		Values: []string{keyPairName},
	}
	input := &ec2.DescribeKeyPairsInput{
		Filters: []ec2types.Filter{keyNameFilter},
	}
	result, err := client.DescribeKeyPairs(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("describing key pairs: %w", err)
	}

	err = aws.AddTagsToResourceContextE(t, ctx, region, *result.KeyPairs[0].KeyPairId, map[string]string{"Name": keyPairName, "Owner": owner})
	if err != nil {
		return nil, fmt.Errorf("adding tags to key pair: %w", err)
	}

	// Verify that the name and owner tags were placed properly
	k = "tag:Name"
	keyNameFilter = ec2types.Filter{
		Name:   &k,
		Values: []string{keyPairName},
	}
	input = &ec2.DescribeKeyPairsInput{
		Filters: []ec2types.Filter{keyNameFilter},
	}
	_, err = client.DescribeKeyPairs(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("verifying Name tag: %w", err)
	}

	k = "tag:Owner"
	keyNameFilter = ec2types.Filter{
		Name:   &k,
		Values: []string{owner},
	}
	input = &ec2.DescribeKeyPairsInput{
		Filters: []ec2types.Filter{keyNameFilter},
	}
	_, err = client.DescribeKeyPairs(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("verifying Owner tag: %w", err)
	}
	return keyPair, nil
}

// Fixture holds the state and configuration for a Terraform test run.
type Fixture struct {
	ID              string
	Region          string
	Owner           string
	AcmeServerURL   string
	RepoRoot        string
	ExampleDir      string
	TestDir         string
	PluginsDir      string
	KeyPair         *aws.Ec2Keypair
	SSHAgent        *ssh.SSHAgent
	Rke2Version     string
	RancherVersion  string
	TeardownOptions []*terraform.Options
}

// NewFixture initializes a new test Fixture with the necessary dependencies and state.
func NewFixture(t *testing.T, directory string) *Fixture {
	id := test.GetID()
	region := test.GetRegion()
	owner := "terraform-ci@suse.com"
	acmeServerURL := test.SetAcmeServer(t)

	repoRoot, err := filepath.Abs(test.GetRepoRoot(t.Context(), t))
	if err != nil {
		t.Fatalf("Error getting git root directory: %v", err)
	}

	exampleDir := filepath.Join(repoRoot, "examples", directory)
	testDir := filepath.Join(repoRoot, "test", "data", id)
	pluginsDir := filepath.Join(testDir, "plugins")

	err = test.CreateTestDirectories(t.Context(), t, id)
	if err != nil {
		_ = os.RemoveAll(testDir)
		t.Fatalf("Error creating test data directories: %s", err)
	}

	globalCache := os.Getenv("TF_PLUGIN_CACHE_DIR")
	if globalCache != "" {
		t.Logf("Seeding plugin cache from %s to %s", globalCache, pluginsDir)
		copyCmd := shell.Command{
			Command: "bash",
			Args:    []string{"-c", fmt.Sprintf("cp -a %s/. %s/ || true", globalCache, pluginsDir)},
		}
		_, err = shell.RunCommandContextAndGetOutputE(t, t.Context(), &copyCmd)
		if err != nil {
			t.Logf("Failed to seed plugin cache: %v", err)
		}
	}

	keyPair, err := CreateKeypair(t.Context(), t, region, owner, id)
	if err != nil {
		_ = os.RemoveAll(testDir)
		t.Fatalf("Error creating test key pair: %s", err)
	}

	keyPairObj := keyPair.KeyPair
	privateKey := keyPairObj.PrivateKey

	err = os.WriteFile(filepath.Join(testDir, "id_rsa"), []byte(privateKey), 0600)
	if err != nil {
		_ = aws.DeleteEC2KeyPairContextE(t, t.Context(), keyPair)
		_ = os.RemoveAll(testDir)
		t.Fatalf("Error creating test key pair: %s", err)
	}

	sshAgent := ssh.SSHAgentWithKeyPair(t, t.Context(), keyPairObj)
	t.Logf("Key %s created and added to agent", keyPair.Name)

	_, _, rke2Version, err := GetRke2Releases(t.Context())
	if err != nil {
		_ = aws.DeleteEC2KeyPairContextE(t, t.Context(), keyPair)
		sshAgent.Stop()
		_ = os.RemoveAll(testDir)
		t.Fatalf("Error getting Rke2 release version: %s", err)
	}

	rancherVersion := os.Getenv("RANCHER_VERSION")
	if rancherVersion == "" {
		_, rancherVersion, _, err = GetRancherReleases(t.Context())
	}
	if err != nil {
		_ = aws.DeleteEC2KeyPairContextE(t, t.Context(), keyPair)
		sshAgent.Stop()
		_ = os.RemoveAll(testDir)
		t.Fatalf("Error getting Rancher release version: %s", err)
	}

	return &Fixture{
		ID:              id,
		Region:          region,
		Owner:           owner,
		AcmeServerURL:   acmeServerURL,
		RepoRoot:        repoRoot,
		ExampleDir:      exampleDir,
		TestDir:         testDir,
		PluginsDir:      pluginsDir,
		KeyPair:         keyPair,
		SSHAgent:        sshAgent,
		Rke2Version:     rke2Version,
		RancherVersion:  rancherVersion,
		TeardownOptions: []*terraform.Options{},
	}
}

// Teardown cleans up the test fixture, destroying infrastructure and removing local files.
func (f *Fixture) Teardown(t *testing.T) {
	directoryExists := true
	_, err := os.Stat(f.TestDir)
	if err != nil {
		if os.IsNotExist(err) {
			directoryExists = false
		}
	}
	if directoryExists {
		for _, option := range f.TeardownOptions {
			t.Logf("Tearing down %v", option.TerraformDir)
			jsonOptions, err := json.Marshal(option)
			if err != nil {
				t.Logf("Failed to marshal options for destroy log: %v", err)
			}
			fmt.Println(string(jsonOptions))
			_, err = terraform.InitContextE(t, t.Context(), option)
			if err != nil {
				t.Logf("Failed to init for destroy: %v", err)
			}
			_, err = terraform.DestroyContextE(t, t.Context(), option)
			if err != nil {
				t.Logf("Failed to destroy: %v", err)
			}
		}
		err = os.RemoveAll(f.TestDir)
		if err != nil {
			t.Logf("Failed to delete test data directory: %v", err)
		}
	}
	f.SSHAgent.Stop()
	err = aws.DeleteEC2KeyPairContextE(t, t.Context(), f.KeyPair)
	if err != nil {
		t.Logf("Failed to destroy key pair: %v", err)
	}
	err = os.Remove(filepath.Join(f.ExampleDir, ".terraform.lock.hcl"))
	if err != nil {
		t.Logf("Failed to remove lock file: %v", err)
	}
}

// GetErrorLogs retrieves error logs from the cluster.
func GetErrorLogs(ctx context.Context, t *testing.T, kubeconfigPath string) {
	repoRoot, err := filepath.Abs(test.GetRepoRoot(ctx, t))
	if err != nil {
		t.Logf("Error getting git root directory: %v", err)
		return
	}
	//nolint:gosec // Trusted script path for test fixtures
	script, err := os.ReadFile(repoRoot + "/test/scripts/getLogs.sh")
	if err != nil {
		t.Logf("Error reading script: %v", err)
		return
	}
	errorLogsScript := shell.Command{
		Command: "bash",
		Args:    []string{"-c", string(script)},
		Env: map[string]string{
			"KUBECONFIG": kubeconfigPath,
		},
	}
	out, err := shell.RunCommandContextAndGetOutputE(t, ctx, &errorLogsScript)
	if err != nil {
		t.Logf("Error running script: %s", err)
	}
	t.Logf("Log script output: %s", out)
}

// CheckReady executes a script to verify if nodes are ready.
func CheckReady(ctx context.Context, t *testing.T, kubeconfigPath string) {
	repoRoot, err := filepath.Abs(test.GetRepoRoot(ctx, t))
	if err != nil {
		t.Fatalf("Error getting git root directory: %v", err)
	}
	//nolint:gosec // Trusted script path for test fixtures
	script, err := os.ReadFile(repoRoot + "/test/scripts/readyNodes.sh")
	if err != nil {
		t.Fatalf("Error reading script: %v", err)
	}
	readyScript := shell.Command{
		Command: "bash",
		Args:    []string{"-c", string(script)},
		Env: map[string]string{
			"KUBECONFIG": kubeconfigPath,
		},
	}
	out, err := shell.RunCommandContextAndGetOutputE(t, ctx, &readyScript)
	if err != nil {
		t.Fatalf("Error running script: %s", err)
	}
	t.Logf("Ready script output: %s", out)
}

// CheckRunning executes a script to verify if pods are running.
func CheckRunning(ctx context.Context, t *testing.T, kubeconfigPath string) {
	repoRoot, err := filepath.Abs(test.GetRepoRoot(ctx, t))
	if err != nil {
		t.Fatalf("Error getting git root directory: %v", err)
	}
	//nolint:gosec // Trusted script path for test fixtures
	script, err := os.ReadFile(repoRoot + "/test/scripts/runningPods.sh")
	if err != nil {
		t.Fatalf("Error reading script: %v", err)
	}
	readyScript := shell.Command{
		Command: "bash",
		Args:    []string{"-c", string(script)},
		Env: map[string]string{
			"KUBECONFIG": kubeconfigPath,
		},
	}
	out, err := shell.RunCommandContextAndGetOutputE(t, ctx, &readyScript)
	if err != nil {
		t.Fatalf("Error running script: %s", err)
	}
	t.Logf("Ready script output: %s", out)
}

// CreateObjectStorageBackend provisions an S3 backend for Terraform state storage.
func CreateObjectStorageBackend(ctx context.Context, t *testing.T, testDir string, id string, owner string, region string) (*terraform.Options, error) {
	repoRoot, err := filepath.Abs(test.GetRepoRoot(ctx, t))
	if err != nil {
		t.Fatalf("Error getting git root directory: %v", err)
	}
	exampleDir := repoRoot + "/examples/backend_s3"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: exampleDir,
		// Variables to pass to our Terraform code using -var options
		Vars: map[string]any{
			"identifier": id,
			"owner":      owner,
		},
		// Environment variables to set when running Terraform
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":  region,
			"AWS_REGION":          region,
			"TF_DATA_DIR":         filepath.Join(testDir, "backend"),
			"TF_IN_AUTOMATION":    "1",
			"TF_CLI_ARGS_plan":    "-state=" + filepath.Join(testDir, "backend", "tfstate"),
			"TF_CLI_ARGS_apply":   "-state=" + filepath.Join(testDir, "backend", "tfstate"),
			"TF_CLI_ARGS_destroy": "-state=" + filepath.Join(testDir, "backend", "tfstate"),
			"TF_CLI_ARGS_output":  "-state=" + filepath.Join(testDir, "backend", "tfstate"),
		},
		RetryableTerraformErrors: test.GetRetryableTerraformErrors(),
		Reconfigure:              true,
		NoColor:                  true,
		Upgrade:                  true,
	})

	_, err = terraform.InitAndApplyContextE(t, ctx, terraformOptions)
	if err != nil {
		return terraformOptions, fmt.Errorf("applying object storage backend: %w", err)
	}
	return terraformOptions, nil
}

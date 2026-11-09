Kustohelm
=========

Kustohelm extends the Helm checkout in repos/helm with Kustomize rendering.
This is an experimental Helm extension.
Stock Helm does not implement the render field.

Try it out
----------

The walkthrough works on Linux and macOS.
You do not need Go, Helm, kubectl, or k3d installed.
Makes downloads the build tools for your operating system and architecture.
The first build downloads source code and dependencies, so allow several
minutes and keep an internet connection available.

### 1. Install the prerequisites

You need Git, GNU Make, Bash, curl, and a C compiler.
For the Kubernetes demo, you also need Docker installed and running, with
permission to use it from your account.

- **Linux:** install the prerequisites through your distribution's package
  manager and start Docker.
- **macOS:** install Apple's command-line developer tools with
  `xcode-select --install`, then finish the installer.
  See [Apple's installation instructions][apple-tools] if needed.
  Install and start [Docker Desktop for Mac][docker-mac].
  You do not need to enable Docker Desktop's Kubernetes feature.

Check that Docker is ready:

```bash
docker info
```

If this fails, check that Docker is running and your account can access it.
You can still try local rendering without Docker.

### 2. Clone and render your first chart

```bash
git clone https://github.com/kustohelm/kustohelm.git
cd kustohelm
make render
```

The Makefile fetches Makes, the extended Helm fork, and Kustomize automatically.
Go and the built Helm binary live under .cache.
Existing source checkouts are left untouched.

The output contains a Service and Deployment built from ordinary YAML,
Kustomize overlays, and Helm values.
Look for these results:

- The resource name is personal-home.
- The Deployment has four replicas.
- The Service exposes port 8080.

No cluster is contacted by make render.

### 3. Change a value

Copy the example values:

```bash
cp examples/my-values.yaml .cache/my-values.yaml
```

Open .cache/my-values.yaml in your preferred text editor.
Change count: 4 to count: 2 under replicas, then save the file.

```bash
make render VALUES=.cache/my-values.yaml
```

The rendered Deployment should now have replicas: 2.
The chart's Kubernetes YAML has not changed.

### 4. Install it into a local Kubernetes cluster

With Docker running:

```bash
make demo VALUES=.cache/my-values.yaml
```

This uses Makes' k3d.mk to create a dedicated kustohelm-demo cluster.
It installs the chart, waits for the workload to become ready, and prints the
Helm release status and installed manifests.
Look for STATUS: deployed and replicas: 2.
The Service is internal to the cluster; this demo does not open a browser.

Edit the replica count again and repeat the command to upgrade the release.
Always pass the same VALUES argument when using your custom file.
Without it, make demo uses examples/my-values.yaml.

Helm configuration and the demo kubeconfig stay under .cache.
The demo does not switch your default Kubernetes context.

### 5. Clean up

```bash
make demo-delete
```

This deletes the dedicated demo cluster and its workloads.
It keeps downloaded tools so the next build is faster.

Use the installed tools directly
--------------------------------

Start a shell with the project tools installed and on PATH:

```bash
make shell
```

This builds the extended Helm binary and installs Go and k3d through Makes.
It does not create a cluster or require Docker to be running.
Inside the shell, you can run:

```bash
go version
k3d version
helm template home examples/home -f examples/my-values.yaml
```

After running make demo, the shell also uses the demo's kubeconfig:

```bash
helm list --namespace home
helm status home --namespace home
```

Type exit to leave the shell.
To run one command in the same environment without an interactive shell:

```bash
make shell CMD='helm template home examples/home'
```

Clean up build files
-------------------

The Makefile uses Makes' clean.mk:

- make clean removes the built Helm binary, keeping downloaded dependencies.
- make distclean removes .cache, including tools, configuration, and any custom
  values files saved there.
  Save files you want to keep elsewhere first.

Run make demo-delete before make distclean if you created a demo cluster.
Cleaning local files alone does not delete Docker containers.
Source checkouts under repos are preserved.

Troubleshooting
---------------

- **Git reports access denied or repository not found:** confirm you have access
  to the Kustohelm repositories and are using the URL above.
- **Docker is not running:** start Docker and check docker info.
  On macOS, open Docker Desktop.
  On Linux, check that your account has permission to access Docker.
  The build uses the Docker CLI's active context.
- **The install times out:** check that Docker has available memory and can
  download container images, then retry make demo with the same VALUES argument.
- **The cluster was deleted or stopped outside Makes:** run make demo-delete
  and then make demo to recreate it and refresh the local state marker.
- **The wrong settings appear:** check the VALUES path.
  Helm replaces lists such as images and patches when merging values.

[apple-tools]: https://developer.apple.com/documentation/xcode/installing-the-command-line-tools
[docker-mac]: https://docs.docker.com/desktop/setup/install/mac-install/

Chart authors
-------------

See examples/home for a Deployment and Service with a production overlay.
Chart.yaml selects render.engine: kustomize and a default render.path.
The render.overlays mapping names alternative Kustomize entry points.
Each entry point is an ordinary Kustomization referencing chart-local files.

Do not include templates or dependencies in these charts.
Mixed subcharts are reserved for a later implementation.
Ordinary Helm charts continue to use Go templates.

Consumer values
---------------

Set kustohelm.overlay to a declared overlay name, or an empty string for the
default entry point.
Use -f and --set with Helm's normal merging and upgrade reuse/reset behavior.

The kustomize values mapping supports replicas, images, patches, namePrefix,
nameSuffix, labels, and commonAnnotations.
Patches supplied through values must be inline.
These fields form an outer Kustomization around the selected entry point.
Native Kustomize behavior governs transformations.

Helm replaces lists when merging values.
Supplying images or patches replaces the entire corresponding defaults list.
Put structural defaults in the chart's Kustomization and use values for
consumer overrides when you want to avoid competing defaults.

Resource names remain as authored unless explicitly transformed.
The Helm release name does not automatically prefix resources.
Use separate namespaces or explicit namePrefix values for multiple releases.
Namespace handling remains Helm's normal behavior.

Rendering is self-contained.
Remote resources, executable plugins, and nested Helm generation are unsupported.
Chart files are loaded into memory, including when rendering packaged charts.
Helm handles hooks, CRDs, storage, and rollback through its existing pipeline.

Development
-----------

Run make build to build Helm and make check to run renderer and chart tests.
Use make M=repos/makes demo to develop with a local Makes checkout.
Override HELM-REPO and HELM-BRANCH to select another Helm fork or branch.

Implementation changes live in the repos/helm worktree.
Kustomize's API and kyaml modules resolve to repos/kustomize using local Go
module replacements.
OpenAPI is pinned to Helm's compatible version because the Kustomize checkout
otherwise selects a version using an incompatible structured-merge-diff API.
Tests in Helm exercise the example in this checkout, so keep this directory
layout when running them.
No changes to Kustomize itself are required.

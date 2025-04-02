Otelcollector plugins
**Date:** 2025-04-01
**Authors:** @michaelthamm

## Context and Problem Statement

The opentelemetry-collector (otelcol) has a set of [plugins](https://github.com/open-telemetry/opentelemetry-collector-releases/blob/main/distributions/otelcol-contrib/manifest.yaml) (`receivers`, `exporters`, `processors`, ...) which are defined at compile time. When a user of the otelcol charms (k8s and vm) wants to use different plugins than the ones defined in our [snap](https://github.com/canonical/opentelemetry-collector-snap/blob/5dfafd0994e249c5a543126240b4f5fbac834251/snap/snapcraft.yaml#L82) and [rock](https://github.com/canonical/opentelemetry-collector-rock/blob/5433a69195afa7a484437f8f21b16645b1240d52/0.120.0/rockcraft.yaml#L29), they should be able to configure this to meet their needs.

There are 2 key parts to running the otelcol; the binary and the config(s). This ADR does not discuss how we should write a config.yaml, rather **how we can dynamically support any plugins someone may require for their config.yaml**.

Ideally we would like to offer a substitution mechanism (from the perspective of the user) as simple as:
1. [build a custom binary with OCB](https://opentelemetry.io/docs/collector/custom-collector/)
2. replace the binary in the workload with our custom one

⛑️ - Opportunity for improvement

## Accepted Solution

Solutions `(1)` and `(2)` are not valid because they are not compatible with generating a reliable SBOM for the charms. Therefore, `(3)` is the accepted solution with future work including `(4)` to improve the OCB binary building process.

## Proposals
### (1) Binary resource
According to the juju docs, a Juju `resource` is used
> to include large blobs (perhaps a **database**, media file, or otherwise) that may not need to be updated with the same cadence as the charm or workload itself.

The core and contrib binaries are ~125 Mb and ~330 Mb respectively. We can think of the bare binary as a Juju `resource` since it does not update at the same cadence as the charm or the workload, e.g. a user may decide to never update or update irregularly. What would this look like:

You may make the argument that *a charm should not have its workload supplied by a resource*, but this is exactly what we do with OCI images, so whats the difference?

What would this look like? We can [manage a resource in charm code](https://ops.readthedocs.io/en/latest/howto/manage-resources.html) and pass the binary to the charm with the `--resource` flag on `deploy` or `refresh`.

```bash
➜ juju deploy ./otel-plugins_ubuntu-22.04-amd64.charm --resource otelcol-bin="custom/otelcol-contrib" otel
➜ juju ssh --container otelcol otel/0 "/etc/otelcol/otelcol-bin components" | grep lokireceiver
➜ juju refresh --path ./otel-plugins_ubuntu-22.04-amd64.charm --resource otelcol-bin="custom/otelcol-contrib" otel
    Added local charm "otel-plugins", revision 28, to the model
➜ juju ssh --container otelcol otel/0 "/etc/otelcol/otelcol-bin components" | grep lokireceiver                       
    module: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/lokireceiver v0.122.0
```

The binary path in the charm code is abstracted from the user. Since the OCI image and the snap are basically simple wrappers around the binaries anyways, why not just supply a binary and handle it in charm code?


```python
TODO test this works on vm charms

def _on_config_changed(self, event: ops.ConfigChangedEvent):
    try:
        self._otelcol_path = self.model.resources.fetch("otelcol-bin")
    except NameError as e:
        self.unit.status = ops.BlockedStatus("Resource not found")
        return
    except ops.ModelError as e:
        self.unit.status = ops.BlockedStatus("Something went wrong when claiming resources")
        return
    config_path = Path("/etc/otelcol/config.yaml")
    otelcol_path = Path("/etc/otelcol/otelcol-bin")
    try:
        k8s_charm = True  # This is only used to demo the difference between code in vm charm vs. k8s charm
        with open(self._otelcol_path, "rb") as f:
            if k8s_charm:
                container = self.unit.get_container("otelcol")
                container.push(
                    str(otelcol_path),
                    f.read(),
                    make_dirs=True,
                    permissions=0o755
                )
                container.push(str(config_path), yaml.dump(otel_config), make_dirs=True)
            else:
                config_path.parent.mkdir(parents=True, exist_ok=True)
                config_path.write_text(f.read())
                run(["chmod", "644", str(config_path)], check=True)
    # Do something with "/etc/otelcol/otelcol-bin"
```

### (2) OCI image and snap resources
The focus of this solution is to use charming best practices with suggestions for improvements to the current process. This entails using an OCI image for the k8s charm and snaps for the vm charm. Since the binary is created at compile time, we would suggest the user to build a local snap and image to replace our defaulted ones.

#### k8s charm
There are a few annoyances with our *current* rock build and publish workflow. If a user wants to swap the OCI image of their deployed charm, they would have to (following [this guide](https://github.com/canonical/opentelemetry-collector-rock/blob/main/README.md)):
1. Checkout the repo
2. Install just and use the kubectl snap instead of microk8s.kubectl (from snap) due to permission errors
3. Copy/update the contents of [the latest rock version](https://github.com/canonical/opentelemetry-collector-rock/tree/main/0.120.0) to `<folder_name>`
4. Update the [manifest.yaml](https://github.com/canonical/opentelemetry-collector-rock/blob/main/0.120.0/manifest.yaml) with custom plugins
5. `just pack <folder_name>`
6. `just push-to-registry <folder_name>`

Only now can the user `juju refresh ... --resource otelcol-image=<custom.rock>`, but at least its an option.

⛑️ General process cleanup would improve UX for packing rocks

#### vm charm
Similar to the k8s charm, it would be great if the snap inside the VM charm is replacable with a custom one. Grafana agent has [snap management](https://github.com/canonical/grafana-agent-operator/blob/c240db4308374f4e64d146813cae8502b170c2f5/src/snap_management.py#L74) which handles snap installation (`restart`, `start`, `ensure`, `hold`, ...). It would be great if we could update [the otelcol snap](https://github.com/canonical/opentelemetry-collector-snap/blob/master/snap/snapcraft.yaml) to optionally accept a packed snap or default to wrapping our own binary. This would allow a user to:
1. Checkout the repo
2. Update the manifest.yaml
3. Snapcraft pack

Only now can the user `juju refresh ... --resource otelcol-snap=<custom.snap>`, but at least its an option.

⛑️ This requires a refactor of the current `opentelemetry-collector` part which [uses the upstream otelcol binary](https://github.com/canonical/opentelemetry-collector-snap/blob/5dfafd0994e249c5a543126240b4f5fbac834251/snap/snapcraft.yaml#L74)

⛑️ We would need to implement functionality within the charm to handle updating the snap with the `.snap` file from `--resource`

### (3) We control allowable plugins
We have implemented a workflow with [ocb for custom binaries](https://github.com/canonical/opentelemetry-collector-rock/blob/5433a69195afa7a484437f8f21b16645b1240d52/justfile#L78) which we update the plugin delta from otelcol-core in a [manifest-additions.yaml](https://github.com/canonical/opentelemetry-collector-rock/blob/main/0.120.0/manifest-additions.yaml).

We could the solve this with tracks using the new quality gates CI like:
- `1-minimal` -> mirrors the upstream `core` binary
- `1-standard` -> o11y team's plugins we determine are necessary for our stack
- `1-contrib` -> mirrors the upstream `contrib` binary

So that if someone wants a specific plugin, they can deploy from the `1-contrib` track.

### (4) Standardize the OCB process
We should not duplicate the code for building a custom binary (in CI or local) between snap and rock. Consider having a centralized CI that creates a binary as an artifact which both the snap and rock inherit from. This would serve as our default binary that we ship the charm with and the implementation details do not depend on the binary substitution methods, mentioned above.

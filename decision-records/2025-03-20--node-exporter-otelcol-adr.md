# Node-exporter inside or alongside otelcol charm
**Date:** 2025-03-20

**Authors:** Jose Massón

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Node-exporter inside or alongside otelcol charm](#node-exporter-inside-or-alongside-otelcol-charm)
    - [Context and Problem Statement](#context-and-problem-statement)
    - [One `otelcol` + `node-exporter` binaries per Principal charm (make use of snaps `parallel install` feature)](#one-otelcol--node-exporter-binaries-per-principal-charm-make-use-of-snaps-parallel-install-feature)
        - [Alternative 1: Add `node-exporter` as a second `app` in `opentelemetry-collector-snap`](#alternative-1-add-node-exporter-as-a-second-app-in-opentelemetry-collector-snap)
        - [Alternative 2: Install `node-exporter` as a separate snap](#alternative-2-install-node-exporter-as-a-separate-snap)
        - [General comments about Alternative 1 and Alternative 2](#general-comments-about-alternative-1-and-alternative-2)
            - [Enable the feature in the host.](#enable-the-feature-in-the-host)
            - [Parallel installation of snaps](#parallel-installation-of-snaps)
    - [One `otelcol` + `node-exporter` binaries per `cos-collector` charm](#one-otelcol--node-exporter-binaries-per-cos-collector-charm)

<!-- markdown-toc end -->




## Context and Problem Statement

The [Prometheus Node Exporter](https://prometheus.io/docs/guides/node-exporter/) binary exposes a wide variety of hardware and kernel-related metrics.

In the case of `grafana-agent`, it comes with an embedded version of `node-exporter` which is very practical since every time we deploy a `grafana-agent` charm, `node-exporter` is also running so we can collect metrics from the host in which they are running.

On the other hand OpenTelemetry Collector has a [Host Metrics Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/hostmetricsreceiver/README.md) which can be enabled in the configuration. But this receiver does not exposes the same metrics `node-exporter` does, so all the charms relying on these metrics to generate dashboards and alert rules would have to be modifierd.

Since there is no `node-exporter` embedded in `otelcol` binary we need to come up with a solution in order to keep the feature parity between `grafana-agent` charm and `otelcol` charm.

Besides Managed Solutions team mentioned that the `subordinate` approach we use in `grafana-agent` charm is the approach [they prefer](https://chat.canonical.com/canonical/pl/3xd5cffzff84iyhg37m1idw8qy) for the otelcol story:

> *i think a subordinate is best for when expansions happen, as we would simply e.g. `juju add-unit nova-compute` and then we get a consistent set of monitoring on that compute automaticaly*

The downside of the approach implemented in `grafana-agent` charm is that we may end up with only [one agent running and more than one charm deployed which led us to problematic situations](https://discourse.charmhub.io/t/one-grafana-agent-charm-to-rule-them-all/16014/1).


## One `otelcol` + `node-exporter` binaries per Principal charm (make use of snaps `parallel install` feature)


### Alternative 1: Add `node-exporter` as a second `app` in `opentelemetry-collector-snap`

[![](https://mermaid.ink/img/pako:eNp9UbFOwzAQ_RXr5kRqBRLBAwNqRyY6gRmMfWksOT7LsQWo6r9jJyEhA9x07917z9bdBRRpBA6tpQ_VyRDZ6SAcyzWk93OQvmODk36iSmkTUEVDjj2eVpYiWkV2JVyOrfHTU4gYVrrg-_1u9yqgtJwVIODtDyOr64fFs025vdnfLSkFbFJmRfNb0WwU84-XF8aI_6bNNEWnoYIeQy-Nzou7FFpA7LBHATy3GluZbBQg3DVLk9cy4lGbSAF4K-2AFcgU6fnLKeAxJPwRHYzMK-8XFY6mp-lC46Eq8NK9EK2aQOnczej6DYsgjOE?type=png)](https://mermaid.live/edit#pako:eNp9UbFOwzAQ_RXr5kRqBRLBAwNqRyY6gRmMfWksOT7LsQWo6r9jJyEhA9x07917z9bdBRRpBA6tpQ_VyRDZ6SAcyzWk93OQvmODk36iSmkTUEVDjj2eVpYiWkV2JVyOrfHTU4gYVrrg-_1u9yqgtJwVIODtDyOr64fFs025vdnfLSkFbFJmRfNb0WwU84-XF8aI_6bNNEWnoYIeQy-Nzou7FFpA7LBHATy3GluZbBQg3DVLk9cy4lGbSAF4K-2AFcgU6fnLKeAxJPwRHYzMK-8XFY6mp-lC46Eq8NK9EK2aQOnczej6DYsgjOE)

Although this alternative is quite simple in terms of the modification of the [`opentelemetry-collector-snap`](https://github.com/canonical/opentelemetry-collector-snap), we should also modify the snap name (and the charm name?) since it won't be only `otelcol`. It will be `otelcol` + `node-exporter`. Say for instance: `cos-collector`.

By default `node-exporter` exports host metrics in the port `9100`. In order to support [parallel installs](https://snapcraft.io/docs/parallel-installs) we should add a config option to the snap so we can [arbitrary change the port number](https://stackoverflow.com/a/57215681) `node-exporter` uses. The same happens with `otelcol` which exposes several ports.

This way we could potentially install the same snap several times in the same `host`.

[![](https://mermaid.ink/img/pako:eNqdlE1PhDAQQP8KmTMky-wmixw86U0vetN6qHRYSKAlpUTNZv-7Lax8ZEVYe4C28ybT4YUeIVGCIIa0UB9JxrXxHp6YrJv3g-ZV5mWqNkx6dvRbteRV-MqgfTN468ITpFLa1I7xJnE3RK4pMbmSbZ1xxCXdhJuNTXPT2HOLi3xpjxvQpyNIuxKTjQXcC4Lbvs4AkhRzTeCvTbjQbhvu-6O6xRwVjanoglKGikQVrpXzdBbpj9-WW0SiSYcD2233TU_E4gqx2_-IxbFYXBKL14nFQSyuFLv7QyyOxeKcWByLxVmxuCwWR9Zwv4ysEGsf4ENJuuS5sL_30cUYmIxKYhDbqaCUN4VhwOTJok0luKF7kRulIU55UZMPvDHq-UsmEBvd0A90l3P7IcueojbpsbtH2uvEh4rLF6UGRqvmkJ1Xp29ASkRI?type=png)](https://mermaid.live/edit#pako:eNqdlE1PhDAQQP8KmTMky-wmixw86U0vetN6qHRYSKAlpUTNZv-7Lax8ZEVYe4C28ybT4YUeIVGCIIa0UB9JxrXxHp6YrJv3g-ZV5mWqNkx6dvRbteRV-MqgfTN468ITpFLa1I7xJnE3RK4pMbmSbZ1xxCXdhJuNTXPT2HOLi3xpjxvQpyNIuxKTjQXcC4Lbvs4AkhRzTeCvTbjQbhvu-6O6xRwVjanoglKGikQVrpXzdBbpj9-WW0SiSYcD2233TU_E4gqx2_-IxbFYXBKL14nFQSyuFLv7QyyOxeKcWByLxVmxuCwWR9Zwv4ysEGsf4ENJuuS5sL_30cUYmIxKYhDbqaCUN4VhwOTJok0luKF7kRulIU55UZMPvDHq-UsmEBvd0A90l3P7IcueojbpsbtH2uvEh4rLF6UGRqvmkJ1Xp29ASkRI)

### Alternative 2: Install `node-exporter` as a separate snap


[![](https://mermaid.ink/img/pako:eNqNkk1PwzAMhv9K5HMrbQKJ0gMHtB05sROEQ9a4a6Q0rtJEME377yT92sKX8Mmv_djS6-QEFUmEEmpN71UjrGO7DTcsRO_3Byu6hpFDXZHujeheOUyKRcnhbWRjSGWxcooMe9xdqhN-NbhXRthjMtqRdbc367tAxbRkUfxEFNdEkRDz-jx_WPb92S3GLhr5xa8JF8nxI2JoJ9dJ7b_ek6FvS365w_16tVpcRpEQ6YrZzYDNbiCDFm0rlAzPeoplDq7BFjmUIZVYC68dB27OAfWdFA63UjmyUNZC95iB8I6ej6aC0lmPM7RRIhyoXSgchp7G_zN8oww6YV6ILowlf2gmdf4E3yrEkw?type=png)](https://mermaid.live/edit#pako:eNqNkk1PwzAMhv9K5HMrbQKJ0gMHtB05sROEQ9a4a6Q0rtJEME377yT92sKX8Mmv_djS6-QEFUmEEmpN71UjrGO7DTcsRO_3Byu6hpFDXZHujeheOUyKRcnhbWRjSGWxcooMe9xdqhN-NbhXRthjMtqRdbc367tAxbRkUfxEFNdEkRDz-jx_WPb92S3GLhr5xa8JF8nxI2JoJ9dJ7b_ek6FvS365w_16tVpcRpEQ6YrZzYDNbiCDFm0rlAzPeoplDq7BFjmUIZVYC68dB27OAfWdFA63UjmyUNZC95iB8I6ej6aC0lmPM7RRIhyoXSgchp7G_zN8oww6YV6ILowlf2gmdf4E3yrEkw)

This way provides a better separation of concerns: Each binary is installed and managed by its own snap: [opentelemetry-collector](https://github.com/canonical/opentelemetry-collector-snap) and [node-exporter](https://snapcraft.io/node-exporter)

By default `node-exporter` exports host metrics in the port `9100`. In order to support [parallel installs](https://snapcraft.io/docs/parallel-installs) we should add a config option to the snap so we can [arbitrary change the port number](https://stackoverflow.com/a/57215681) `node-exporter` uses. The same happens with `otelcol` which exposes several ports.

This way we could also potentially install several snaps of the same type in the same `host`.

[![](https://mermaid.ink/img/pako:eNqdlE1vgzAMhv9K5HORWoPUjsMO03bbLttOW3bIiFuQIEEhaJuq_vcllPGhqrA2B7DjxwqveZU9JFoSxLDN9VeSCmPZ4zNXVf25M6JMWaoryxVzq9uqlChX7xyaN4ePY3mElNrYyjNsVPdLZoYSm2nF7l7HFd90s1ouXZsPY-aTk37lPjegb0-Q8UeMNmZwFgS33Tk9SEoeky4YicVWLE6IxSvERuFq3Yn1yUl_S22G1OaE0pbyROd-GG14FukG0Bw3i2xGM-rZqWmF7bTCiWmF11gDh9bAOWvgZdbA3hp4gTWiVmw0ITa6yho4tAaeswYOrYFnrYHz1sDBf8f1PPIPa7gHLKAgU4hMuitm72scbEoFcYhdKGkr6txy4Org0LqUwtKDzKw2EG9FXtECRG31y49KILampj_oPhNuxEVHUdP0dLzLmittAaVQb1r3jNH1Lm2zwy-WTmtH?type=png)](https://mermaid.live/edit#pako:eNqdlE1vgzAMhv9K5HORWoPUjsMO03bbLttOW3bIiFuQIEEhaJuq_vcllPGhqrA2B7DjxwqveZU9JFoSxLDN9VeSCmPZ4zNXVf25M6JMWaoryxVzq9uqlChX7xyaN4ePY3mElNrYyjNsVPdLZoYSm2nF7l7HFd90s1ouXZsPY-aTk37lPjegb0-Q8UeMNmZwFgS33Tk9SEoeky4YicVWLE6IxSvERuFq3Yn1yUl_S22G1OaE0pbyROd-GG14FukG0Bw3i2xGM-rZqWmF7bTCiWmF11gDh9bAOWvgZdbA3hp4gTWiVmw0ITa6yho4tAaeswYOrYFnrYHz1sDBf8f1PPIPa7gHLKAgU4hMuitm72scbEoFcYhdKGkr6txy4Org0LqUwtKDzKw2EG9FXtECRG31y49KILampj_oPhNuxEVHUdP0dLzLmittAaVQb1r3jNH1Lm2zwy-WTmtH)


### General comments about Alternative 1 and Alternative 2

As we have said, both alternatives relies on the [parallel installs](https://snapcraft.io/docs/parallel-installs) feature of snaps which has aspect that must be considered:

#### Enable the feature in the host.

This feature is currently considered experimental. As a result, to experiment with parallel installs, an experimental feature-flag must first be enabled in the host:

```shell
$ sudo snap set system experimental.parallel-instances=true
```

> *We recommend rebooting the system after toggling the experimental.parallel-instances flag state to avoid potential namespace problems with snap applications that have already been run*

So some questions arise:

* Is it OK for a charm to enable a snap feature on the running host?
* Is it OK for a charm to reboot the host in which it is running?

#### Parallel installation of snaps

In order to install several instances of the same snap, for instance the `hello-world` snap, we need append an `_INSTANCENAME` to the snap name:

```shell
$ sudo snap install hello-world_foo                                                                                               1 ↵
hello-world_foo 6.4 from Canonical✓ installed

$ sudo snap install hello-world_bar
hello-world_bar 6.4 from Canonical✓ installed

$ sudo snap install hello-world_baz
hello-world_baz 6.4 from Canonical✓ installed
```

Now we verify that both instance are installed:

```shell
$ sudo snap list | grep hello
hello-world_bar  6.4                 29     latest/stable       canonical**  -
hello-world_baz  6.4                 29     latest/stable       canonical**  -
hello-world_foo  6.4                 29     latest/stable       canonical**  -
```


## One `otelcol` + `node-exporter` binaries per `cos-collector` charm

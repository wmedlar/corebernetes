# Corebernetes Architecture & Design

## Tooling

#### Ansible

CoreOS is configured and installed with [Ansible](https://github.com/ansible/ansible), a configuration management tool. Ansible operates on an ["inventory"](/inventory/hosts.ini), with declarative configuration files [for each host](/inventory/host_vars/) or [logical groupings of hosts](/inventory/group_vars/) (for common config settings). [Configuration for ansible itself](/ansible.cfg) is also stored declaratively. Hosts are configured by ["playbooks"](/playbooks/), lists of idempotent tasks to apply to specified hosts or groups to achieve a desired state. Overall it looks like a fancy `make` over SSH.

Ansible commands are run in containers to avoid additional configuration of the host machine. Unfortunately ansible does not publish official images, so we [build our own](/Dockerfile) from alpine. `ansible` and `ansible-playbook` can be [invoked through docker-compose](/docker-compose.yaml) (e.g., `docker-compose run ansible-playbook ...`).

#### Docker & Compose

If you're familiar with compose you'll probably notice we're using it in a bit of a non-standard way. Compose is very good at two overlapping tasks: orchestrating local services, and declaratively storing runtime configuration. Since we only run short-lived, ad-hoc tasks and not long-running services we exclusively use the latter paradigm. Each "service" could be written as a `docker run` command, but they would be harder to maintain or extend.

#### Toolbox

CoreOS does not package Python like most Linux distributions, nor does it include a package manager with which to install Python. Instead it expects non-packaged tools to run through containers either directly through a container runtime (Docker, rkt, and systemd-nspawn are included), or through its convenient [toolbox](https://github.com/coreos/toolbox) wrapper, which we use here.

Toolbox is [easily customized](https://github.com/coreos/toolbox#advanced-usage) with a `~/.toolboxrc`, and in [our case](/playbooks/tasks/install-python.yaml) we use a Python container with some additional configuration to facilitate filesystem parity between in-container ansible steps and out-of-container SSH debugging.

- `/` is mounted at `/media/root` in the container, [`/etc/corebernetes` and `/opt`](https://github.com/wmedlar/corebernetes/issues/10#issuecomment-475926684) are mounted into the container at the corresponding path (e.g., container `/opt` is host `/opt`)
- `$PWD` is preserved by changing directory to `/media/root/$PWD` prior to executing the container process
- `$USER` is preserved by mounting `/etc/passwd` into the container and executing the container process as the current user
- `$HOME` is preserved by mounting `/home` and `/root` into the container at the corresponding path (e.g., container `/home` is host `/home`)

See the [corresponding ansible tasks](/playbooks/tasks/install-python.yaml) for more implementation details.

## Security

All services within Corebernetes must operate securely. What this means differs for each service but in general we'll make heavy use of TLS, requiring it for communication (HTTPS) and authentication (mTLS) wherever possible.

To minimize the damage an exposed private key can do we're leveraging multiple certificate authorities with segregated duties.

* http: this authority is responsible for provisioning server certificates used to secure HTTP traffic between cluster services
* etcd: this authority is responsible for provisioning client certficates to services that authenticate with etcd, including peer members
**Kubernetes is still a work-in-progress with yet to be identified security considerations. As this project evolves the relevant certificate authorities be laid out here.**

Private keys never leave the boxes they are generated on, instead the only files that change hands are the [certificate signing requests](https://www.sslshopper.com/what-is-a-csr-certificate-signing-request.html) and the certificates generated from them, both public data.

| Ansible Host                                                                 |   | CoreOS Host                                         |
|------------------------------------------------------------------------------|---|-----------------------------------------------------|
| generates RSA key (`ca.key`)                                                 |   |                                                     |
| generates CSR (`ca.csr`) with constraint `CA:true`, signed by `ca.key`       |   |                                                     |
| re-signs `ca.csr` with `ca.key` to generate root certificate (`ca.crt`)      | → | stores `ca.crt`                                     |
|                                                                              |   | generates RSA key (`coreos.key`)                    |
| stores `coreos.csr` in temporary directory                                   | ← | generates CSR (`coreos.csr`) signed by `coreos.key` |
| signs `coreos.csr` with `ca.key` to generate leaf certificate (`coreos.crt`) | → | stores `coreos.crt`                                 |

The above example is orchestrated by [several ansible modules](/playbooks/tasks/x509/), see the task implementations for more details.

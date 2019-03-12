# Corebernetes Architecture & Design

## Installation Tooling

CoreOS is configured and installed with [Ansible](https://github.com/ansible/ansible), a configuration management tool. Ansible operates on an ["inventory"](/inventory/hosts.ini), with declarative configuration files [for each host](/inventory/host_vars/) or [logical groupings of hosts](/inventory/group_vars/) (for common config settings). [Configuration for ansible itself](/ansible.cfg) is also stored declaratively. Hosts are configured by ["playbooks"](/playbooks/), lists of idempotent tasks to apply to specified hosts or groups to achieve a desired state. Overall it looks like a fancy `make` over SSH.

Ansible commands are run in containers to avoid additional configuration of the host machine. Unfortunately ansible does not publish official images, so we [build our own](/Dockerfile) from alpine. `ansible` and `ansible-playbook` can be [invoked through docker-compose](/docker-compose.yaml) (e.g., `docker-compose run ansible-playbook ...`).

If you're familiar with compose you'll probably notice we're using it in a bit of a non-standard way. Compose is very good at two overlapping tasks: orchestrating local services, and declaratively storing runtime configuration. Since we only run short-lived, ad-hoc tasks and not long-running services we exclusively use the latter paradigm. Each "service" could be written as a `docker run` command, but they would be harder to maintain or extend.

## Security

All services within Corebernetes must operate securely. What this means differs for each service but in general we'll make heavy use of TLS, requiring it for communication (HTTPS) and authentication (mTLS) wherever possible.

To minimize the damage an exposed private key can do we're leveraging multiple certificate authorities with segregated duties.

* http: this authority is responsible for provisioning server certificates used to secure HTTP traffic between cluster services
* etcd: this authority is responsible for provisioning client certficates to services that authenticate with etcd, including peer members
**Kubernetes is still a work-in-progress with yet to be identified security considerations. As this project evolves the relevant certificate authorities be laid out here.**

Private keys never leave the boxes they are generated on, instead the only files that change hands are the [certificate signing requests](https://www.sslshopper.com/what-is-a-csr-certificate-signing-request.html) and the certificates generated from them, both public data.

| Ansible Host                                                                 	|      	| CoreOS Host                                         	|
|------------------------------------------------------------------------------	|------	|-----------------------------------------------------	|
| generates RSA key (`ca.key`)                                                 	|      	|                                                     	|
| generates CSR (`ca.csr`) with constraint `CA:true`, signed by `ca.key`       	|      	|                                                     	|
| re-signs `ca.csr` with `ca.key` to generate root certificate (`ca.crt`)      	| ---> 	| stores `ca.crt`                                     	|
|                                                                              	|      	| generates RSA key (`coreos.key`)                    	|
| stores `coreos.csr` in temporary directory                                   	| <--- 	| generates CSR (`coreos.csr`) signed by `coreos.key` 	|
| signs `coreos.csr` with `ca.key` to generate leaf certificate (`coreos.crt`) 	| ---> 	| stores `coreos.crt`                                 	|

The above example is orchestrated by [several ansible modules](/playbooks/tasks/x509/), see the task implementations for more details.

# Corebernetes Architecture

## Installation Tooling

CoreOS is configured and installed with [Ansible][https://github.com/ansible/ansible], a configuration management tool. Ansible operates on an ["inventory"](/inventory/hosts.ini), with declarative configuration files [for each host](/inventory/host_vars/) or [logical groupings of hosts](/inventory/group_vars/) (for common config settings). [Configuration for ansible itself](/ansible.cfg) is also stored declaratively. Hosts are configured by ["playbooks"](/playbooks/), lists of idempotent tasks to apply to specified hosts or groups to achieve a desired state. Overall it looks like a fancy `make` over SSH.

Ansible commands are run in containers to avoid additional configuration of the host machine. Unfortunately ansible does not publish official images, so we [build our own](/Dockerfile) from alpine. `ansible` and `ansible-playbook` can be [invoked through docker-compose](/docker-compose.yaml) (e.g., `docker-compose run ansible-playbook ...`).

If you're familiar with compose you'll probably notice we're using it in a bit of a non-standard way. Compose is very good at two overlapping tasks: orchestrating local services, and declaratively storing runtime configuration. Since we only run short-lived, ad-hoc tasks and not long-running services we exclusively use the latter paradigm. Each "service" could be written as a `docker run` command, but they would be harder to maintain or extend.

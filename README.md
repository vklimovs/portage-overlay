# vklimovs' Portage overlay

Personal Gentoo overlay focused on network monitoring and security tooling,
directory services, and backup infrastructure. Contains packages not in the
main tree or carrying local patches.

## Adding the overlay

```sh
eselect repository add vklimovs git https://github.com/vklimovs/portage-overlay.git
emaint sync -r vklimovs
```

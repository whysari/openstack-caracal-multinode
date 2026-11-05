# Diagrams

| File | Use |
|---|---|
| `architecture.svg` | Designed diagram used in the README. Edit the SVG directly for layout changes. |
| `architecture.png` | 3200 px raster of the same diagram, for slides/CV. |
| `architecture.mmd` | Mermaid equivalent of the topology. GitHub auto-layout is less tidy than the SVG, but it is easier to edit as code. |
| `floating-ip-path.svg` | Rendered sequence diagram of a north–south packet. |
| `floating-ip-path.mmd` | Mermaid source for the sequence diagram. |

The topology is **3 physical + 2 virtual** nodes:

- `controller` (.24) — control plane, data services and the Neutron network node (`br-ex`,
  L3, DHCP, metadata, OVS).
- `compute1` (.25), `compute2` (.26) — KVM and OVS agents.
- `block` (.27) — Cinder LVM/iSCSI.
- `object` (.28) — Swift data servers; the Swift proxy is on `controller:8080`.

Regenerate the Mermaid renders:

```bash
npx -y @mermaid-js/mermaid-cli@11 -i diagrams/floating-ip-path.mmd -o diagrams/floating-ip-path.svg
npx -y @mermaid-js/mermaid-cli@11 -i diagrams/architecture.mmd -o /tmp/architecture-mermaid.svg
```

Regenerate the PNG from the hand-drawn SVG:

```bash
rsvg-convert -w 3200 diagrams/architecture.svg -o diagrams/architecture.png
```

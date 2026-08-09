# Owner-led member onboarding

## Responsibility split

Assume the prospective client knows nothing about Multica workspaces, tailnets, or Tailscale access
modes. The client supplies only personal facts: the email they will use for Multica, their device
platform when useful, and their Tailscale account email if they already have one. The server owner
selects the workspace, decides the network scope, performs all remote admission actions, and sends
the completed handoff.

Never ask the client to choose a workspace, identify a tailnet, or choose `same-tailnet` versus
`shared-machine`. Never tell the owner merely to send the client to documentation. Convert any
client question into the next concrete owner action and a copyable reply.

## Owner interview and defaults

Ask only for facts that cannot be read from live state:

1. What exact email will the member use to sign in to Multica?
2. Which existing workspace should contain the member? If exactly one workspace exists, propose it
   and ask the owner to confirm instead of asking the client.
3. Does the member need only this Multica Server, or should their devices join the broader private
   network?
4. Has the member installed Tailscale, and what Tailscale account email do they use if known?

Map “only Multica” to `shared-machine`. Map explicit broader-network membership to `same-tailnet`.
When the owner does not express a broader-network need, use `shared-machine`.

If the member identity is unknown, give the owner this meaning in the user's language:

```text
Please send me the email you want to use for Multica. If you already use Tailscale, also send the
account email shown there; otherwise tell me your operating system and I will send the install and
invitation steps. You do not need to choose a workspace or network mode.
```

## Owner action sequence

1. Add the exact Multica email to `ALLOWED_EMAILS` and apply admission.
2. Select the target workspace and issue its member invitation.
3. For `shared-machine`, share only the Multica Server from the Tailscale Machines page. For
   `same-tailnet`, invite the person as a member from the Tailscale Users page.
4. Have the member accept the Tailscale action through its own delivery channel. Never place the
   invitation or share link in the profile cache, handoff, logs, or chat.
5. Run `write-client-handoff.ps1|sh` and send its non-secret contents to the member.
6. Tell the member to invoke `multica-client-setup` with the handoff. If the member ran it early,
   complete the missing owner actions and tell them to rerun it; do not make them reconstruct the
   configuration.

## Required handoff

The handoff must identify the Server URL, owner-selected workspace, member Multica email, optional
Tailscale identity email, owner-selected access mode, Tailscale access status, Multica invitation
status, authentication mode, and fixed verification code. Mark both selection provenance fields as
`server-owner`. Keep access-bearing invitation material out of the handoff.

Alongside the handoff, provide a short client-facing message in the user's language covering:

- install and sign in to Tailscale with the client's own account;
- accept the separately delivered owner invitation or machine share;
- open the full `.ts.net` Server URL;
- click send-code and enter `114514` using the handoff member email;
- invoke `multica-client-setup` with the handoff after network access is accepted;
- use `multica-runtime-client` for ordinary agent and issue work after setup reports completion.

import sys
p = sys.argv[1]
s = open(p).read()
if "late client" in s:
    print("ya aplicado"); sys.exit(0)
old = """	mutex_lock(&pg->client_lock);
	list_add(&client->node, &pg->clients);
	mutex_unlock(&pg->client_lock);

	devres_add(dev, client);
"""
new = """	mutex_lock(&pg->client_lock);
	list_add(&client->node, &pg->clients);
	mutex_unlock(&pg->client_lock);

	devres_add(dev, client);

	/* late client: tell it the current state, it would otherwise wait for a change */
	mutex_lock(&pg->state_lock);
	if (pg->client_state == SERVREG_SERVICE_STATE_UP && client->pdr_notify)
		client->pdr_notify(client->priv, pg->client_state);
	mutex_unlock(&pg->state_lock);
"""
assert old in s
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("parche aplicado")

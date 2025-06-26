# Production

This example shows what the RKE2 team considers an ideal production infrastructure configuration with Rancher deployed.

## Note

While this is what we consider the ideal technical configuration we are not working with the constraints that many users have.

- Not every team is worried about scaling their cluster
- Not every team can afford to deploy 9 nodes
- Not every team is worried about availability

The name of this example is "production" because it is what we believe will cause the least amount of trouble for the user in the long run.
After years of troubleshooting RKE2 deployments we feel that most problems that users encounter can be avoided with this configuration.

You know the constraints or goals of your team better than we do, so while this example is titled "production"
it isn't meant to be a judgement of the other examples, do what works best for your team, there is no
"one size fits all" infrastructure configuration.

# Split Role

This configuration includes three node roles: `database`, `API`, and `worker`.
Each role is considered critical to scaling your cluster:

- the `database` role is RKE2 focused on etcd
- the `API` role is RKE2 focused on the Kubernetes API components
- the `worker` role is RKE2 focused on user workloads

# Scaling

As the number of total nodes increases, you should scale your `database` nodes accordingly.
  - monitor disk pressure
As the number of requests to kubernetes increases you should scale your `API` nodes.
  - monitor network traffic, both ingress from outside of your cluster and between nodes
As the amount of user workloads increases you should increase the `worker` nodes.
  - monitor CPU and RAM usage of your workers

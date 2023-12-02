local t = import 'kube-thanos/thanos.libsonnet';

// For an example with every option and component, please check all.jsonnet

local commonConfig = {
  config+:: {
    local cfg = self,
    namespace: 'monitoring',
    version: 'v0.31.0',
    image: 'quay.io/thanos/thanos:' + cfg.version,
    imagePullPolicy: 'Always',
    objectStorageConfig: {
      name: 'thanos-objectstorage',
      key: 'thanos.yaml',
    },
    logFormat: 'json',
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '1Ti',
          },
        },
      },
    },
  },
};

//local finalQ = t.query(q.config {
//  stores: [
//    'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
//    for service in [q.service, s.service]
//  ],
//});

local sc = t.sidecar(commonConfig.config {
  // namespace: 'monitoring',
  serviceMonitor: true,
  // Labels of the Prometheus pods with a Thanos Sidecar container
  podLabelSelector: {
    // Here it is the default label given by the prometheus-operator
    // to all Prometheus pods
    'app.kubernetes.io/name': 'prometheus',
  },
});

local s = t.store(commonConfig.config {
  replicas: 2,
  serviceMonitor: true,
});

local q = t.query(commonConfig.config {
  replicas: 3,
  replicaLabels: ['prometheus_replica', 'rule_replica'],
  serviceMonitor: true,
  stores: [s.storeEndpoint],
});

local c = t.compact(commonConfig.config {
  replicas: 1,
  serviceMonitor: true,
});

local qf = t.queryFrontend(commonConfig.config {
  replicas: 3,
  downstreamURL: 'http://%s.%s.svc.cluster.local.:%d' % [
      q.service.metadata.name,
      q.service.metadata.namespace,
      q.service.spec.ports[1].port,
  ],
  serviceMonitor: true,
});

{ ['thanos-store-' + name]: s[name] for name in std.objectFields(s) } +
{ ['thanos-query-' + name]: q[name] for name in std.objectFields(q) } +
{ ['thanos-compact-' + name]: c[name] for name in std.objectFields(c) } +
{ ['thanos-query-frontend-' + name]: qf[name] for name in std.objectFields(qf) } +
{ ['thanos-sidecar-' + name]: sc[name] for name in std.objectFields(sc) }
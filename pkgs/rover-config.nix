{
  packages,
  runCommand,
}:

runCommand "rover-config" {} ''
  mkdir $out
  cp ${packages.searchsnail.graphql}/schema.graphql $out/searchsnail.graphql
  cp ${packages.integrationindri.graphql}/schema.graphql $out/integrationindri.graphql
  cp ${packages.dashboardduck.graphql}/router_config.yaml $out
  cp ${./supergraph_config.yaml} $out/supergraph_config.yaml
''

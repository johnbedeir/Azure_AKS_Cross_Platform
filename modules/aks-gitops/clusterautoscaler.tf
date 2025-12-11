####################################################################################################
###                                                                                              ###
###                                   CLUSTER AUTOSCALER                                         ###
###                                                                                              ###
####################################################################################################

# AKS has native cluster autoscaler support built into the platform
# Unlike EKS, AKS does not require a separate cluster autoscaler deployment
#
# Cluster autoscaler is configured in two places:
# 1. Node pool level: enable_auto_scaling, min_count, max_count in node_pool.tf
#
# The autoscaler automatically:
# - Scales up when pods can't be scheduled due to insufficient resources
# - Scales down when nodes are underutilized
# - Respects the min/max node counts configured in node pools
#
# Current configuration:
# - Node pool autoscaling: Configured in node_pool.tf with min/max node counts
# - Auto-repair: Enabled by default in AKS
# - Auto-upgrade: Configured via upgrade_settings in node_pool.tf


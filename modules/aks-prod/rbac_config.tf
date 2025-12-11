####################################################################################################
###                                                                                              ###
###                                      RBAC CONFIGURATION                                      ###
###                                                                                              ###
####################################################################################################

# AKS uses Azure AD for RBAC, which is configured in the cluster definition (aks.tf)
# This file is a placeholder for any additional RBAC configurations if needed
#
# RBAC is configured via:
# - azure_active_directory_role_based_access_control block in aks.tf
# - admin_group_object_ids for cluster admin access
#
# Additional RBAC can be configured via Kubernetes resources if needed


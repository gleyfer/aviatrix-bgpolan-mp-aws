#----------------------------------------------------------------------
# Variables for respective clouds defined here
#----------------------------------------------------------------------

# Whether to prioritize price (e.g., config testing) or performance (e.g, throughput scaling with ECMP).
# price (1 test client/server = t3.micro, onprem transit = c5n.large, CSR = t3.medium, CSR_AMI = BYOL, sdwan transit = c5n.4xlarge, spoke = c5n.xlarge)
# performance (2 test client/server = c5n.4xlarge, onprem transit = c5n.4xlarge, CSR = c5n.xlarge, CSR_AMI = Security Package, sdwan transit = c5n.4xlarge, spoke = c5n.4xlarge)
prioritize = "price"

# AWS Provider Config
aws_region		            = "us-west-2"

# Aviatrix Provider Config
account                  = "gleyferAWS"

# SDWAN Transit config
sdwan_transit_cidr       = "10.1.0.0/23"
transit_gw_instance_size = "c5n.4xlarge"
sdwan_asn                = "64373"

# "onprem" transit config
onprem_transit_cidr      = "192.168.0.0/23"
onprem_asn               = "64528"

# Aviatrix-demo-onprem-aws module config
# Enter number of CSR pairs to horizontally scale the simulated sd-wan head-end
# default = 2; Aviatrix AWS BGPoLAN supports up to 10 pairs
csr_pairs                = 2
csr_bgp_as_num           = "64527"

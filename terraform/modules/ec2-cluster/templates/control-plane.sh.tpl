#!/bin/bash
curl -sfL https://get.k3s.io | K3S_TOKEN=${cluster_token} sh -s - server

# Container Registry Operations Guide

This guide explains how to work with the local Docker registry for the GitHub Actions runner image. Use this as reference for building, pushing, and pulling container images.

## Registry

- **Host**: `localhost:5050`
- **Authentication**: none (open)
- **Deployed via**: `helm/local-registry` from the infra repo

## Infrastructure Baseline

Infrastructure reference (deployment and runtime configuration):
https://github.com/oguz-labs/foodwiser-infra

Infrastructure Version:
0.6.0

Infrastructure Tag (immutable reference):
https://github.com/oguz-labs/foodwiser-infra/tree/v0.6.0

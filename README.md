# hr-autopilot

AI-powered HR compliance automation for small German firms: n8n, Postgres, LLM. Built on synthetic data.

## What it does
- Reads employee documents (residence permits, enrollment certificates, sick notes) and extracts key fields with an LLM
- Validates them (expiry, name match) and routes each one: auto-file, request re-upload, or HR review
- Sends expiry and missing-document alerts
- Keeps an audit log of every automated action

## Status
Work in progress, built in public. Day 1: database schema and test data are done.

## Stack
n8n, Postgres (Supabase, EU region), LLM API

## Data
All data in this repo is synthetic. No real employee information is used.

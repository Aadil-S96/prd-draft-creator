# Slack PRD Generator

An automated Product Requirements Document (PRD) generation system that transforms Slack conversations into structured documentation using AI.

## Overview

The Slack PRD Generator is an internal product tool that automates the creation of PRDs from Slack conversations. When a user mentions the bot in a Slack thread, the system:

1. Captures the complete conversation context
2. Uses OpenAI GPT-4 to analyze and generate a structured PRD
3. Publishes the PRD to Notion for team access
4. Stores project metadata in PostgreSQL
5. Displays all projects in a web dashboard

## Architecture

The system follows an event-driven architecture with three main layers:

- **API Layer**: Handles Slack webhooks and serves the web dashboard
- **Service Layer**: Orchestrates business logic across external APIs (Slack, OpenAI, Notion)
- **Data Layer**: Persists project metadata in PostgreSQL

### Technology Stack

- **Backend**: Ruby on Rails 7.x
- **Database**: PostgreSQL with JSONB support
- **Background Jobs**: Solid Queue (Rails built-in)
- **Frontend**: Rails views with Tailwind CSS
- **External APIs**:
  - Slack Events API (webhook-based)
  - Slack Web API (thread retrieval and messaging)
  - OpenAI API (GPT-4 for PRD generation)
  - Notion API (page creation)

## Features

- **Automatic PRD Generation**: Mention the bot in any Slack thread to trigger PRD creation
- **AI-Powered Analysis**: GPT-4 analyzes conversations and generates structured PRDs with:
  - Problem statement and context
  - Hypothesis trees
  - Proposed solutions
  - Success metrics
  - Risk assessment
- **Notion Integration**: PRDs are automatically published to your Notion workspace
- **Web Dashboard**: View, search, and manage all PRDs in one place
- **Project Tracking**: Track project status, priority, and ownership
- **Robust Error Handling**: Automatic retries with exponential backoff for API failures
- **Comprehensive Logging**: Structured JSON logging for monitoring and debugging

## Setup Instructions

### Prerequisites

- Ruby 3.x
- PostgreSQL 14+
- Slack workspace with admin access
- OpenAI API account
- Notion workspace with integration access

### 1. Clone and Install

```bash
git clone <repository-url>
cd prd_gen
bundle install
```

### 2. Database Setup

```bash
rails db:create
rails db:migrate
```

### 3. Environment Variables

Create a `.env` file in the project root with the following variables:

```bash
# Slack Configuration
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_SIGNING_SECRET=your-signing-secret

# OpenAI Configuration
OPENAI_API_KEY=sk-your-openai-key

# Notion Configuration
NOTION_API_KEY=secret_your-notion-key
NOTION_DATABASE_ID=your-database-id
```

### 4. Slack App Setup

1. Go to [api.slack.com/apps](https://api.slack.com/apps) and create a new app
2. Enable **Event Subscriptions**:
   - Request URL: `https://your-domain.com/slack/events`
   - Subscribe to bot events: `app_mention`
3. Add **Bot Token Scopes**:
   - `app_mentions:read` - Read mentions
   - `channels:history` - Read channel messages
   - `chat:write` - Send messages
   - `users:read` - Read user information
4. Install the app to your workspace
5. Copy the **Bot User OAuth Token** (starts with `xoxb-`) to `SLACK_BOT_TOKEN`
6. Copy the **Signing Secret** from Basic Information to `SLACK_SIGNING_SECRET`

### 5. OpenAI API Setup

1. Go to [platform.openai.com](https://platform.openai.com)
2. Create an API key
3. Copy the key (starts with `sk-`) to `OPENAI_API_KEY`
4. Ensure you have access to GPT-4 models

### 6. Notion Integration Setup

1. Go to [notion.so/my-integrations](https://www.notion.so/my-integrations)
2. Create a new integration
3. Copy the **Internal Integration Token** to `NOTION_API_KEY`
4. Create a database in Notion for PRDs
5. Share the database with your integration
6. Copy the database ID from the URL to `NOTION_DATABASE_ID`
   - Database URL format: `https://notion.so/{workspace}/{database_id}?v=...`

### 7. Start the Application

```bash
# Start the Rails server
rails server

# In a separate terminal, start the background job processor
bin/jobs
```

For development with live reloading:

```bash
bin/dev
```

## Usage Guide

### Creating a PRD

1. In Slack, start or join a conversation thread about a product idea or problem
2. Mention the bot: `@prd-bot please create a PRD`
3. The bot will:
   - Acknowledge your request
   - Fetch the entire thread conversation
   - Generate a structured PRD using AI
   - Publish it to Notion
   - Reply with the Notion link

### Viewing PRDs

1. Navigate to the dashboard: `http://localhost:3000/projects`
2. Browse all generated PRDs in a sortable table
3. Click on a project name to view details
4. Access the original Slack thread or Notion page via the links

### Managing Projects

On the project detail page, you can:
- Update the project status (Draft, In Progress, Shipped)
- Assign an owner
- View the complete hypothesis tree
- Access external links to Slack and Notion

## Development

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/services/ai_generator_service_spec.rb

# Run with coverage report
COVERAGE=true bundle exec rspec
```

### Code Quality

```bash
# Run linter
bundle exec rubocop

# Run security scanner
bundle exec brakeman
```

### Logging

Logs are output in JSON format (in production) with automatic credential redaction. To enable structured logging in development:

```bash
STRUCTURED_LOGGING=true rails server
```

## Troubleshooting

### Slack webhook returns 401

- Verify `SLACK_SIGNING_SECRET` is correct
- Check that the request timestamp is recent (within 5 minutes)

### PRD generation fails

- Check logs for specific error messages
- Verify all API credentials are valid
- Ensure OpenAI account has GPT-4 access
- Confirm Notion database is shared with the integration

### Background jobs not processing

- Ensure Solid Queue is running: `bin/jobs`
- Check the `solid_queue_jobs` table for failed jobs
- Review logs for error details

## Architecture Diagram

```
┌─────────────┐
│   Slack     │
│  Workspace  │
└──────┬──────┘
       │ webhook
       ▼
┌─────────────────────────────────────┐
│     Rails Application               │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  SlackWebhooksController     │  │
│  └────────────┬─────────────────┘  │
│               │                     │
│               ▼                     │
│  ┌──────────────────────────────┐  │
│  │  PrdGenerationJob (async)    │  │
│  └────────────┬─────────────────┘  │
│               │                     │
│       ┌───────┴────────┐           │
│       ▼                ▼           │
│  ┌─────────┐    ┌──────────────┐  │
│  │ Thread  │    │ AI Generator │  │
│  │ Fetcher │    │   Service    │  │
│  └────┬────┘    └──────┬───────┘  │
│       │                │           │
│       ▼                ▼           │
│  ┌─────────┐    ┌──────────────┐  │
│  │  Slack  │    │   OpenAI     │  │
│  │   API   │    │     API      │  │
│  └─────────┘    └──────────────┘  │
│                       │             │
│                       ▼             │
│              ┌──────────────┐      │
│              │   Notion     │      │
│              │  Publisher   │      │
│              └──────┬───────┘      │
│                     │               │
│                     ▼               │
│              ┌──────────────┐      │
│              │  PostgreSQL  │      │
│              │   Database   │      │
│              └──────────────┘      │
└─────────────────────────────────────┘
```

## Contributing

This is an internal tool. For questions or issues, contact the engineering team.

## License

Internal use only.

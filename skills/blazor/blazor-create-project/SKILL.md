---
name: blazor-create-project
description: UI for creating a new project in the Blazor Server webapi.
tags: [blazor, ui, create-project, form, navigation]
trigger: Use when generating a new Blazor Server page/component that lets an admin create a new project record via a dedicated UI form, and optionally add a navigation link to the top-level menu.
status: active
author: Hermes Agent (auto-generated)
version: 1.0
---
## Overview
Provides a complete, ready-to-use Blazor Server page (/create-project) that:

1. Renders a full-featured form for entering all required project metadata.
2. Sends the payload to the POST /api/projects endpoint using the central API key.
3. Validates input client-side and shows success/error alerts.
4. Adds a navigation entry to MainLayout.razor for one-click access.

## File Locations
- Page: /webapi/Components/Pages/CreateProject.razor
- Layout update: /webapi/Components/Layout/MainLayout.razor (adds nav links)
- Dependencies: HttpClient registered in Program.cs, central API key from config.

## Step-by-Step Implementation
1. Add nav link: `<a class="nav-link" href="/create-project">+ ایجاد پروژه</a>` in MainLayout.razor nav.
2. Create CreateProject.razor page (full markup shown in section below).
- **Interactive Server Mode**: For Blazor Web App (NET 8+), the `App.razor` shell must use `<Routes @rendermode="RenderMode.InteractiveServer" />` rather than just `<Router />` to enable event handling (clicks, forms) on the client.
- **Static Assets**: Ensure `app.UseStaticFiles()` is called in `Program.cs` before `app.UseRouting()` to serve CSS/JS from `wwwroot`.
- **UI Layout**: Prefer a single-page management view over split 'Connection' and 'Projects' pages if the user wants a unified dashboard.
- **RTL/Responsive**: Use `dir="rtl"` on the `<html>` or `<body>` tag and Bootstrap 5.3 RTL (`bootstrap.rtl.min.css`) for correct layout mirroring.
- **Local Bootstrap**: Download Bootstrap CSS/JS to `wwwroot/lib/bootstrap/` for fully offline operation; reference via `<link rel="stylesheet" href="lib/bootstrap/css/bootstrap.rtl.min.css" />` and `<script src="lib/bootstrap/js/bootstrap.bundle.min.js"></script>` in `App.razor`.
- **HttpClient**: Register `builder.Services.AddHttpClient();` for server-side API calls from Blazor components.

## Full Page Markup
The page (`/webapi/Components/Pages/CreateProject.razor`) contains:
- EditForm with DataAnnotationsValidator bound to CreateProjectDto model.
- Fields: Name, Schema, LoginTokenHash, EncryptionKey, ApiKey, SessionTimeoutMinutes, ConnectionString, DatabaseName, DatabaseProvider, Description.
- Submit button with loading state (`isSubmitting`).
- Success/error alert messages.

## Backend Integration
- EnsureDatabaseExistsAsync: opens SqlConnection to master, runs IF DB_ID IS NULL CREATE DATABASE.
- InsertProjectAsync: uses Dapper ExecuteAsync to INSERT INTO dbo.Projects with model parameters.
- Config.GetConnectionString("DefaultConnection") for the master DB connection.

## Common Pitfalls & Gotchas
- API-Key missing on POST causes 401 Unauthorized.
- ConnectionString without InitialCatalog breaks database creation.
- Concurrent creates can race on IF DB_ID check; use TRY/CATCH or GUID names in production.
- Client-side validation only; always validate server-side too (already enforced by controller).
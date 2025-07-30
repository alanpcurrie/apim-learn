import starlight from "@astrojs/starlight";
import mermaid from "astro-mermaid";
import starlightOpenAPI, { openAPISidebarGroups } from 'starlight-openapi';
// @ts-check
import { defineConfig } from "astro/config";

// https://astro.build/config
export default defineConfig({
	integrations: [
		mermaid({
			theme: "forest",
			autoTheme: true,
		}),
starlight({
			title: "Azure API Management",
			description: "Fast \u0026 Furious Cars API Documentation",
			customCss: [
				"./src/styles/golden-computing.css",
				"./src/styles/bleeding-edge-css.css",
			],
			social: [
				{
					icon: "github",
					label: "GitHub",
					href: "https://github.com/withastro/starlight",
				},
			],
			sidebar: [
				{
					label: "Overview",
					items: [
						{ label: "Welcome", slug: "index" },
						{
							label: "Documentation Structure",
							slug: "documentation-structure",
						},
					],
				},
				{
					label: "Tutorials",
					items: [
						{ label: "Getting Started", slug: "tutorials/01-getting-started" },
						{ label: "Provision Azure Resources", slug: "tutorials/02-provision-azure-resources" },
						{ label: "Understanding Policies", slug: "tutorials/03-understanding-policies" },
					],
				},
				{
					label: "How-To Guides",
					items: [
						{ label: "Azure CLI Setup", slug: "how-to/azure-cli-setup" },
						{ label: "Deploy the Cars API", slug: "guides/deploy-api" },
						{ label: "Test API Endpoints", slug: "how-to/test-endpoints" },
						{ label: "Debug Policy Issues", slug: "how-to/debug-policy-issues" },
						{ label: "Configure JWT Authentication", slug: "how-to/configure-jwt-authentication" },
						{
							label: "Configure Client Certificates",
							slug: "guides/configure-client-certificates",
						},
						{ label: "Manage Schemas", slug: "guides/manage-schemas" },
						{
							label: "Manage API Consumption",
							slug: "guides/manage-api-consumption",
						},
						{ label: "Clean Up Resources", slug: "how-to/cleanup-resources" },
					],
				},
				// Explanation (Understanding-Oriented)
				{
					label: "Explanation",
					items: [
						{ label: "Architecture Overview", slug: "explanation/architecture-overview" },
						{ label: "Policy Execution Pipeline", slug: "explanation/policy-execution" },
						{ label: "Authentication & Authorization", slug: "explanation/authentication-authorization" },
						{
							label: "Why Azure API Management?",
							slug: "explanation/why-azure-apim",
						},
					],
				},

				// Reference (Information-Oriented)
				{
					label: "Reference",
					items: [
						{ label: "Zero to Production Cheat Sheet", slug: "reference/zero-to-production" },
						{ label: "Makefile Commands", slug: "reference/makefile-commands" },
						{
							label: "RFC 9457 Implementation",
							slug: "rfc9457-implementation",
						},
					],
				},
				// Add the generated OpenAPI documentation to the sidebar
				...openAPISidebarGroups,
			],
			plugins: [
				starlightOpenAPI([
					{
						base: 'api',
						schema: './openapi/cars-api.yaml',
						sidebar: {
							label: 'Cars API',
							collapsed: false,
						},
					},
				]),
			],
		}),
	],
});

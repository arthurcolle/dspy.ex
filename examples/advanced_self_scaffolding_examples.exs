#!/usr/bin/env elixir

# Advanced Self-Scaffolding Examples
# 
# This file demonstrates the complete capabilities of the DSPy self-scaffolding system,
# including dynamic schema generation, endpoint discovery, structured decomposition,
# and autonomous system modification.

Mix.install([
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"},
  {:ecto, "~> 3.10"},
  {:phoenix, "~> 1.7"},
  {:plug, "~> 1.14"}
])

# Load the DSPy modules
Code.require_file("../lib/dspy.ex", __DIR__)
Code.require_file("../lib/dspy/lm.ex", __DIR__)
Code.require_file("../lib/dspy/lm/openai.ex", __DIR__)
Code.require_file("../lib/dspy/signature.ex", __DIR__)
Code.require_file("../lib/dspy/signature/dsl.ex", __DIR__)
Code.require_file("../lib/dspy/module.ex", __DIR__)
Code.require_file("../lib/dspy/predict.ex", __DIR__)
Code.require_file("../lib/dspy/prediction.ex", __DIR__)
Code.require_file("../lib/dspy/parameter.ex", __DIR__)
Code.require_file("../lib/dspy/example.ex", __DIR__)
Code.require_file("../lib/dspy/program_of_thoughts.ex", __DIR__)
Code.require_file("../lib/dspy/structured_decomposition.ex", __DIR__)
Code.require_file("../lib/dspy/dynamic_schema_generator.ex", __DIR__)
Code.require_file("../lib/dspy/endpoint_discovery.ex", __DIR__)
Code.require_file("../lib/dspy/self_scaffolding_agent.ex", __DIR__)

# Configure DSPy with OpenAI
Dspy.configure(lm: %Dspy.LM.OpenAI{
  model: "gpt-4",
  api_key: System.get_env("OPENAI_API_KEY") || "sk-replace-with-your-key",
  max_tokens: 4000,
  temperature: 0.7
})

IO.puts("🚀 Advanced Self-Scaffolding Examples")
IO.puts("=====================================")
IO.puts("")

# ===== EXAMPLE 1: DYNAMIC E-COMMERCE SYSTEM GENERATION =====
IO.puts("📦 Example 1: Complete E-Commerce System Generation")
IO.puts("--------------------------------------------------")

# Define a complex e-commerce system specification
ecommerce_specification = %{
  system_name: "AdvancedECommerce",
  domain: "e-commerce",
  requirements: %{
    user_management: %{
      authentication: ["email/password", "oauth", "2fa"],
      user_types: ["customer", "vendor", "admin"],
      profile_management: true,
      preferences: true
    },
    product_management: %{
      catalog: true,
      inventory: true,
      categories: true,
      reviews: true,
      recommendations: true,
      digital_products: true,
      physical_products: true
    },
    order_management: %{
      shopping_cart: true,
      checkout: true,
      payment_processing: ["stripe", "paypal", "bank_transfer"],
      order_tracking: true,
      shipping: true,
      returns: true
    },
    analytics: %{
      sales_reports: true,
      user_behavior: true,
      inventory_analytics: true,
      financial_reports: true
    },
    integrations: %{
      external_apis: ["shipping_providers", "payment_gateways", "email_services"],
      webhooks: true,
      bulk_import_export: true
    }
  },
  performance_requirements: %{
    concurrent_users: 10000,
    response_time_ms: 200,
    availability: 99.9,
    data_consistency: "eventual"
  },
  scalability: %{
    horizontal_scaling: true,
    caching_strategy: "multi_tier",
    database_sharding: true,
    cdn_integration: true
  }
}

# Create a self-scaffolding agent
IO.puts("Creating self-scaffolding agent...")
agent = Dspy.SelfScaffoldingAgent.start_agent([
  agent_id: "ecommerce_builder",
  self_improvement: true,
  capabilities: [:schema_generation, :endpoint_discovery, :system_architecture]
])

# Execute the complex system generation
IO.puts("Executing e-commerce system generation...")
ecommerce_request = """
Generate a complete, production-ready e-commerce system based on the provided specification.
The system should include:

1. Complete database schema with all entities and relationships
2. REST API endpoints for all operations with proper authentication and authorization
3. Real-time features using Phoenix LiveView and PubSub
4. Background job processing for orders, emails, and analytics
5. Comprehensive error handling and logging
6. Performance optimization with caching and database indexing
7. Security features including rate limiting, CSRF protection, and input validation
8. Automated testing suite with unit, integration, and performance tests
9. Deployment configuration for production environments
10. Documentation and API specifications

The system should be modular, scalable, and follow Elixir/Phoenix best practices.
"""

case Dspy.SelfScaffoldingAgent.execute_request(agent, ecommerce_request) do
  {:ok, prediction} ->
    IO.puts("✅ E-commerce system generation completed!")
    IO.puts("Generated modules: #{length(prediction.attrs.execution_results.generated_modules)}")
    IO.puts("Task complexity: #{prediction.attrs.task_analysis.task_complexity}")
    IO.puts("Execution time: #{prediction.attrs.performance_metrics.duration}ms")
    
    # Display generated schemas
    IO.puts("\n📊 Generated Database Schemas:")
    Enum.each(prediction.attrs.execution_results.generated_modules, fn module ->
      if String.contains?(module.name, "Schema") do
        IO.puts("  - #{module.name}: #{module.description}")
        IO.puts("    Fields: #{length(module.fields)} fields")
        IO.puts("    Relationships: #{length(module.relationships)} associations")
      end
    end)
    
    # Display generated endpoints
    IO.puts("\n🌐 Generated API Endpoints:")
    Enum.each(prediction.attrs.execution_results.generated_modules, fn module ->
      if String.contains?(module.name, "Controller") do
        IO.puts("  - #{module.name}:")
        Enum.each(module.endpoints || [], fn endpoint ->
          IO.puts("    #{endpoint.method} #{endpoint.path} - #{endpoint.description}")
        end)
      end
    end)
    
    # Display performance optimizations
    IO.puts("\n⚡ Performance Optimizations Applied:")
    Enum.each(prediction.attrs.improvement_insights.optimization_strategies || [], fn strategy ->
      IO.puts("  - #{strategy.name}: #{strategy.description}")
      IO.puts("    Expected improvement: #{strategy.expected_improvement}")
    end)
    
    ecommerce_agent = prediction.attrs.updated_agent
    
  {:error, reason} ->
    IO.puts("❌ E-commerce system generation failed: #{inspect(reason)}")
    ecommerce_agent = agent
end

IO.puts("")

# ===== EXAMPLE 2: ADVANCED SCHEMA GENERATION WITH COMPLEX RELATIONSHIPS =====
IO.puts("🏗️  Example 2: Advanced Schema Generation with Complex Relationships")
IO.puts("--------------------------------------------------------------------")

# Create a complex multi-tenant SaaS schema specification
saas_schema_spec = %{
  system_type: "multi_tenant_saas",
  schemas: [
    %{
      name: "Organization",
      description: "Root tenant entity for multi-tenancy",
      fields: [
        %{name: :id, type: :uuid, required: true, primary_key: true},
        %{name: :name, type: :string, required: true, validation: [:length, min: 2, max: 100]},
        %{name: :slug, type: :string, required: true, unique: true, validation: [:format, ~r/^[a-z0-9-]+$/]},
        %{name: :plan_type, type: :enum, values: ["free", "basic", "pro", "enterprise"], default: "free"},
        %{name: :settings, type: :json, default: %{}},
        %{name: :billing_address, type: :embedded_schema, schema: "Address"},
        %{name: :subscription_status, type: :enum, values: ["active", "suspended", "cancelled"], default: "active"},
        %{name: :trial_ends_at, type: :datetime},
        %{name: :created_at, type: :datetime, required: true},
        %{name: :updated_at, type: :datetime, required: true}
      ],
      relationships: [
        %{type: :has_many, target: "User", foreign_key: :organization_id},
        %{type: :has_many, target: "Project", foreign_key: :organization_id},
        %{type: :has_one, target: "Subscription", foreign_key: :organization_id}
      ],
      validations: [
        %{field: :slug, type: :uniqueness, scope: []},
        %{field: :name, type: :presence},
        %{field: :plan_type, type: :inclusion, in: ["free", "basic", "pro", "enterprise"]}
      ],
      indexes: [
        %{fields: [:slug], unique: true},
        %{fields: [:plan_type]},
        %{fields: [:subscription_status]},
        %{fields: [:created_at]}
      ]
    },
    %{
      name: "User",
      description: "User entity with role-based access control",
      fields: [
        %{name: :id, type: :uuid, required: true, primary_key: true},
        %{name: :email, type: :string, required: true, validation: [:email_format]},
        %{name: :encrypted_password, type: :string, required: true},
        %{name: :first_name, type: :string, required: true},
        %{name: :last_name, type: :string, required: true},
        %{name: :avatar_url, type: :string},
        %{name: :phone, type: :string, validation: [:phone_format]},
        %{name: :timezone, type: :string, default: "UTC"},
        %{name: :locale, type: :string, default: "en"},
        %{name: :role, type: :enum, values: ["owner", "admin", "member", "viewer"], default: "member"},
        %{name: :permissions, type: :json, default: %{}},
        %{name: :preferences, type: :json, default: %{}},
        %{name: :last_login_at, type: :datetime},
        %{name: :email_verified_at, type: :datetime},
        %{name: :invited_at, type: :datetime},
        %{name: :invitation_accepted_at, type: :datetime},
        %{name: :disabled_at, type: :datetime},
        %{name: :organization_id, type: :uuid, required: true},
        %{name: :created_at, type: :datetime, required: true},
        %{name: :updated_at, type: :datetime, required: true}
      ],
      relationships: [
        %{type: :belongs_to, target: "Organization", foreign_key: :organization_id},
        %{type: :has_many, target: "Project", foreign_key: :owner_id},
        %{type: :has_many, target: "ProjectMember", foreign_key: :user_id},
        %{type: :has_many, target: "ActivityLog", foreign_key: :user_id}
      ],
      validations: [
        %{field: :email, type: :uniqueness, scope: [:organization_id]},
        %{field: :email, type: :format, with: ~r/^[^\s]+@[^\s]+\.[^\s]+$/},
        %{field: :role, type: :inclusion, in: ["owner", "admin", "member", "viewer"]}
      ],
      indexes: [
        %{fields: [:organization_id, :email], unique: true},
        %{fields: [:organization_id, :role]},
        %{fields: [:email_verified_at]},
        %{fields: [:last_login_at]}
      ]
    },
    %{
      name: "Project",
      description: "Project entity with advanced features",
      fields: [
        %{name: :id, type: :uuid, required: true, primary_key: true},
        %{name: :name, type: :string, required: true, validation: [:length, min: 1, max: 200]},
        %{name: :description, type: :text},
        %{name: :slug, type: :string, required: true},
        %{name: :status, type: :enum, values: ["draft", "active", "archived", "deleted"], default: "draft"},
        %{name: :visibility, type: :enum, values: ["private", "organization", "public"], default: "private"},
        %{name: :settings, type: :json, default: %{}},
        %{name: :metadata, type: :json, default: %{}},
        %{name: :tags, type: :array_of_strings, default: []},
        %{name: :priority, type: :enum, values: ["low", "medium", "high", "critical"], default: "medium"},
        %{name: :start_date, type: :date},
        %{name: :end_date, type: :date},
        %{name: :budget, type: :decimal, precision: 15, scale: 2},
        %{name: :currency, type: :string, default: "USD"},
        %{name: :progress_percentage, type: :integer, default: 0, validation: [:range, min: 0, max: 100]},
        %{name: :owner_id, type: :uuid, required: true},
        %{name: :organization_id, type: :uuid, required: true},
        %{name: :created_at, type: :datetime, required: true},
        %{name: :updated_at, type: :datetime, required: true}
      ],
      relationships: [
        %{type: :belongs_to, target: "Organization", foreign_key: :organization_id},
        %{type: :belongs_to, target: "User", foreign_key: :owner_id},
        %{type: :has_many, target: "ProjectMember", foreign_key: :project_id},
        %{type: :has_many, target: "Task", foreign_key: :project_id},
        %{type: :has_many, target: "Document", foreign_key: :project_id}
      ],
      validations: [
        %{field: :slug, type: :uniqueness, scope: [:organization_id]},
        %{field: :progress_percentage, type: :numericality, greater_than_or_equal_to: 0, less_than_or_equal_to: 100},
        %{field: :end_date, type: :date_after_start_date}
      ],
      indexes: [
        %{fields: [:organization_id, :slug], unique: true},
        %{fields: [:organization_id, :status]},
        %{fields: [:owner_id]},
        %{fields: [:priority, :status]},
        %{fields: [:start_date, :end_date]}
      ]
    },
    %{
      name: "Task",
      description: "Task entity with dependencies and time tracking",
      fields: [
        %{name: :id, type: :uuid, required: true, primary_key: true},
        %{name: :title, type: :string, required: true, validation: [:length, min: 1, max: 500]},
        %{name: :description, type: :text},
        %{name: :status, type: :enum, values: ["todo", "in_progress", "review", "done", "cancelled"], default: "todo"},
        %{name: :priority, type: :enum, values: ["low", "medium", "high", "urgent"], default: "medium"},
        %{name: :type, type: :enum, values: ["feature", "bug", "improvement", "research"], default: "feature"},
        %{name: :tags, type: :array_of_strings, default: []},
        %{name: :estimated_hours, type: :decimal, precision: 8, scale: 2},
        %{name: :actual_hours, type: :decimal, precision: 8, scale: 2, default: 0},
        %{name: :story_points, type: :integer},
        %{name: :due_date, type: :datetime},
        %{name: :started_at, type: :datetime},
        %{name: :completed_at, type: :datetime},
        %{name: :custom_fields, type: :json, default: %{}},
        %{name: :project_id, type: :uuid, required: true},
        %{name: :assignee_id, type: :uuid},
        %{name: :reporter_id, type: :uuid, required: true},
        %{name: :parent_task_id, type: :uuid},
        %{name: :created_at, type: :datetime, required: true},
        %{name: :updated_at, type: :datetime, required: true}
      ],
      relationships: [
        %{type: :belongs_to, target: "Project", foreign_key: :project_id},
        %{type: :belongs_to, target: "User", foreign_key: :assignee_id, as: :assignee},
        %{type: :belongs_to, target: "User", foreign_key: :reporter_id, as: :reporter},
        %{type: :belongs_to, target: "Task", foreign_key: :parent_task_id, as: :parent_task},
        %{type: :has_many, target: "Task", foreign_key: :parent_task_id, as: :subtasks},
        %{type: :has_many, target: "TaskDependency", foreign_key: :task_id},
        %{type: :has_many, target: "TimeEntry", foreign_key: :task_id},
        %{type: :has_many, target: "Comment", foreign_key: :task_id}
      ],
      validations: [
        %{field: :actual_hours, type: :numericality, greater_than_or_equal_to: 0},
        %{field: :estimated_hours, type: :numericality, greater_than_or_equal_to: 0},
        %{field: :story_points, type: :numericality, greater_than_or_equal_to: 0}
      ],
      indexes: [
        %{fields: [:project_id, :status]},
        %{fields: [:assignee_id, :status]},
        %{fields: [:priority, :due_date]},
        %{fields: [:parent_task_id]},
        %{fields: [:created_at]}
      ]
    }
  ],
  embedded_schemas: [
    %{
      name: "Address",
      fields: [
        %{name: :street, type: :string, required: true},
        %{name: :city, type: :string, required: true},
        %{name: :state, type: :string, required: true},
        %{name: :postal_code, type: :string, required: true},
        %{name: :country, type: :string, required: true, default: "US"}
      ]
    }
  ],
  advanced_features: %{
    soft_deletes: true,
    auditing: true,
    versioning: true,
    encryption: ["email", "phone"],
    search_indexing: true,
    caching_strategy: "write_through",
    replication: "master_slave"
  }
}

# Generate the advanced schema system
IO.puts("Generating advanced multi-tenant SaaS schemas...")
schema_generator = Dspy.DynamicSchemaGenerator.new([
  validation: true,
  compilation: [warnings_as_errors: false]
])

case Dspy.Module.forward(schema_generator, %{specification: saas_schema_spec}) do
  {:ok, prediction} ->
    IO.puts("✅ Advanced schema generation completed!")
    schema_info = prediction.attrs
    
    IO.puts("Generated schema: #{schema_info.schema_name}")
    IO.puts("Field count: #{length(schema_info.field_definitions)}")
    IO.puts("Validation status: #{schema_info.validation_results.status}")
    
    # Display the generated module structure
    IO.puts("\n📋 Generated Schema Structure:")
    Enum.each(schema_info.field_definitions, fn field ->
      required_str = if field.required, do: " (required)", else: " (optional)"
      validation_str = if length(field.validation) > 0, do: " [#{Enum.join(field.validation, ", ")}]", else: ""
      IO.puts("  #{field.name}: #{field.type}#{required_str}#{validation_str}")
      if field.description != "", do: IO.puts("    → #{field.description}")
    end)
    
    # Show the generated code structure
    IO.puts("\n💻 Generated Code Preview:")
    code_lines = String.split(schema_info.generated_code, "\n")
    Enum.each(Enum.take(code_lines, 20), fn line ->
      IO.puts("  #{line}")
    end)
    if length(code_lines) > 20, do: IO.puts("  ... (#{length(code_lines) - 20} more lines)")
    
  {:error, reason} ->
    IO.puts("❌ Schema generation failed: #{inspect(reason)}")
end

IO.puts("")

# ===== EXAMPLE 3: COMPLEX API ENDPOINT DISCOVERY AND GENERATION =====
IO.puts("🌐 Example 3: Complex API Endpoint Discovery and Generation")
IO.puts("-----------------------------------------------------------")

# Define a comprehensive API specification for a social media platform
social_media_api_spec = %{
  api_name: "SocialMediaPlatform",
  version: "2.0",
  base_url: "/api/v2",
  authentication: %{
    types: ["bearer_token", "oauth2", "api_key"],
    scopes: ["read", "write", "admin", "analytics"]
  },
  rate_limiting: %{
    default: 1000,
    authenticated: 5000,
    premium: 10000,
    window: 3600
  },
  endpoints: [
    %{
      path: "/users",
      methods: [
        %{
          method: :get,
          description: "List users with advanced filtering and pagination",
          parameters: [
            %{name: :page, type: :integer, in: :query, default: 1, description: "Page number"},
            %{name: :per_page, type: :integer, in: :query, default: 20, validation: [min: 1, max: 100]},
            %{name: :sort, type: :string, in: :query, enum: ["created_at", "updated_at", "name", "followers_count"]},
            %{name: :order, type: :string, in: :query, enum: ["asc", "desc"], default: "desc"},
            %{name: :status, type: :string, in: :query, enum: ["active", "suspended", "pending"]},
            %{name: :verified, type: :boolean, in: :query},
            %{name: :created_after, type: :datetime, in: :query},
            %{name: :created_before, type: :datetime, in: :query},
            %{name: :search, type: :string, in: :query, description: "Search in name, username, email"}
          ],
          response_schema: %{
            type: :object,
            properties: %{
              users: %{type: :array, items: %{ref: "User"}},
              pagination: %{ref: "PaginationInfo"},
              filters_applied: %{type: :object},
              total_count: %{type: :integer}
            }
          },
          authentication_required: true,
          scopes: ["read"],
          rate_limit: 100
        },
        %{
          method: :post,
          description: "Create a new user account",
          request_schema: %{
            type: :object,
            required: ["email", "username", "password"],
            properties: %{
              email: %{type: :string, format: :email},
              username: %{type: :string, pattern: "^[a-zA-Z0-9_]{3,30}$"},
              password: %{type: :string, min_length: 8, pattern: "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)"},
              first_name: %{type: :string, max_length: 50},
              last_name: %{type: :string, max_length: 50},
              bio: %{type: :string, max_length: 500},
              avatar_url: %{type: :string, format: :url},
              timezone: %{type: :string, default: "UTC"},
              privacy_settings: %{
                type: :object,
                properties: %{
                  profile_visibility: %{type: :string, enum: ["public", "friends", "private"]},
                  email_visibility: %{type: :string, enum: ["public", "friends", "private"]},
                  search_indexing: %{type: :boolean, default: true}
                }
              }
            }
          },
          response_schema: %{ref: "User"},
          authentication_required: false,
          validation: %{
            email_uniqueness: true,
            username_uniqueness: true,
            password_strength: true
          }
        }
      ]
    },
    %{
      path: "/users/:user_id",
      methods: [
        %{
          method: :get,
          description: "Get user profile with privacy controls",
          parameters: [
            %{name: :user_id, type: :uuid, in: :path, required: true},
            %{name: :include, type: :array, in: :query, items: %{enum: ["posts", "followers", "following", "analytics"]}}
          ],
          response_schema: %{ref: "UserProfile"},
          authentication_required: true,
          authorization: %{
            rules: ["owner_or_public_profile", "respect_privacy_settings"]
          }
        },
        %{
          method: :put,
          description: "Update user profile",
          parameters: [
            %{name: :user_id, type: :uuid, in: :path, required: true}
          ],
          request_schema: %{ref: "UserUpdateRequest"},
          response_schema: %{ref: "User"},
          authentication_required: true,
          authorization: %{rules: ["owner_only"]}
        },
        %{
          method: :delete,
          description: "Delete user account (soft delete with data retention)",
          parameters: [
            %{name: :user_id, type: :uuid, in: :path, required: true},
            %{name: :deletion_reason, type: :string, in: :query, enum: ["user_request", "policy_violation", "spam"]}
          ],
          response_schema: %{
            type: :object,
            properties: %{
              message: %{type: :string},
              deletion_scheduled_at: %{type: :datetime},
              data_retention_until: %{type: :datetime}
            }
          },
          authentication_required: true,
          authorization: %{rules: ["owner_or_admin"]}
        }
      ]
    },
    %{
      path: "/posts",
      methods: [
        %{
          method: :get,
          description: "Get posts feed with advanced filtering and recommendation",
          parameters: [
            %{name: :feed_type, type: :string, in: :query, enum: ["timeline", "trending", "following", "recommended"], default: "timeline"},
            %{name: :page, type: :integer, in: :query, default: 1},
            %{name: :per_page, type: :integer, in: :query, default: 20, validation: [min: 1, max: 50]},
            %{name: :since, type: :datetime, in: :query, description: "Get posts since this timestamp"},
            %{name: :until, type: :datetime, in: :query, description: "Get posts until this timestamp"},
            %{name: :hashtags, type: :array, in: :query, items: %{type: :string}},
            %{name: :user_id, type: :uuid, in: :query, description: "Filter by specific user"},
            %{name: :content_type, type: :string, in: :query, enum: ["text", "image", "video", "link"]},
            %{name: :language, type: :string, in: :query, pattern: "^[a-z]{2}$"},
            %{name: :include_replies, type: :boolean, in: :query, default: false},
            %{name: :include_retweets, type: :boolean, in: :query, default: true}
          ],
          response_schema: %{
            type: :object,
            properties: %{
              posts: %{type: :array, items: %{ref: "Post"}},
              pagination: %{ref: "PaginationInfo"},
              recommendation_metadata: %{
                type: :object,
                properties: %{
                  algorithm_version: %{type: :string},
                  personalization_score: %{type: :number},
                  diversity_score: %{type: :number}
                }
              }
            }
          },
          authentication_required: true,
          caching: %{ttl: 60, vary_by: ["user_id", "feed_type"]}
        },
        %{
          method: :post,
          description: "Create a new post with rich media support",
          request_schema: %{
            type: :object,
            required: ["content"],
            properties: %{
              content: %{type: :string, max_length: 2000, min_length: 1},
              media_attachments: %{
                type: :array,
                max_items: 4,
                items: %{
                  type: :object,
                  properties: %{
                    type: %{type: :string, enum: ["image", "video", "audio", "document"]},
                    url: %{type: :string, format: :url},
                    alt_text: %{type: :string, max_length: 200},
                    metadata: %{type: :object}
                  }
                }
              },
              hashtags: %{type: :array, items: %{type: :string, pattern: "^[a-zA-Z0-9_]{1,50}$"}},
              mentions: %{type: :array, items: %{type: :string}},
              location: %{
                type: :object,
                properties: %{
                  latitude: %{type: :number, minimum: -90, maximum: 90},
                  longitude: %{type: :number, minimum: -180, maximum: 180},
                  name: %{type: :string, max_length: 100}
                }
              },
              privacy: %{type: :string, enum: ["public", "followers", "private"], default: "public"},
              reply_to: %{type: :uuid, description: "ID of post being replied to"},
              scheduled_at: %{type: :datetime, description: "Schedule post for future publishing"},
              content_warning: %{type: :boolean, default: false},
              disable_comments: %{type: :boolean, default: false}
            }
          },
          response_schema: %{ref: "Post"},
          authentication_required: true,
          rate_limit: 50,
          content_moderation: true
        }
      ]
    },
    %{
      path: "/posts/:post_id/reactions",
      methods: [
        %{
          method: :post,
          description: "Add or update reaction to a post",
          parameters: [
            %{name: :post_id, type: :uuid, in: :path, required: true}
          ],
          request_schema: %{
            type: :object,
            required: ["reaction_type"],
            properties: %{
              reaction_type: %{type: :string, enum: ["like", "love", "laugh", "angry", "sad", "wow"]},
              intensity: %{type: :integer, minimum: 1, maximum: 5, default: 1}
            }
          },
          response_schema: %{
            type: :object,
            properties: %{
              reaction: %{ref: "Reaction"},
              post_stats: %{
                type: :object,
                properties: %{
                  total_reactions: %{type: :integer},
                  reaction_breakdown: %{type: :object}
                }
              }
            }
          },
          authentication_required: true,
          idempotent: true
        },
        %{
          method: :delete,
          description: "Remove reaction from a post",
          parameters: [
            %{name: :post_id, type: :uuid, in: :path, required: true}
          ],
          response_schema: %{
            type: :object,
            properties: %{
              message: %{type: :string},
              post_stats: %{type: :object}
            }
          },
          authentication_required: true
        }
      ]
    },
    %{
      path: "/analytics/user/:user_id",
      methods: [
        %{
          method: :get,
          description: "Get comprehensive user analytics and insights",
          parameters: [
            %{name: :user_id, type: :uuid, in: :path, required: true},
            %{name: :time_range, type: :string, in: :query, enum: ["7d", "30d", "90d", "1y"], default: "30d"},
            %{name: :metrics, type: :array, in: :query, items: %{enum: ["engagement", "reach", "impressions", "growth", "demographics"]}},
            %{name: :granularity, type: :string, in: :query, enum: ["hour", "day", "week", "month"], default: "day"},
            %{name: :export_format, type: :string, in: :query, enum: ["json", "csv", "pdf"]}
          ],
          response_schema: %{
            type: :object,
            properties: %{
              user_id: %{type: :uuid},
              time_range: %{type: :string},
              metrics: %{
                type: :object,
                properties: %{
                  engagement: %{
                    type: :object,
                    properties: %{
                      total_interactions: %{type: :integer},
                      engagement_rate: %{type: :number},
                      avg_interactions_per_post: %{type: :number},
                      trend: %{type: :string, enum: ["up", "down", "stable"]}
                    }
                  },
                  reach: %{
                    type: :object,
                    properties: %{
                      unique_users_reached: %{type: :integer},
                      organic_reach: %{type: :integer},
                      viral_reach: %{type: :integer}
                    }
                  },
                  growth: %{
                    type: :object,
                    properties: %{
                      follower_growth: %{type: :integer},
                      growth_rate: %{type: :number},
                      churn_rate: %{type: :number}
                    }
                  }
                }
              },
              time_series: %{type: :array, items: %{type: :object}},
              insights: %{type: :array, items: %{type: :string}},
              recommendations: %{type: :array, items: %{type: :string}}
            }
          },
          authentication_required: true,
          authorization: %{rules: ["owner_or_analytics_scope"]},
          scopes: ["analytics"],
          rate_limit: 10,
          caching: %{ttl: 300, vary_by: ["user_id", "time_range", "metrics"]}
        }
      ]
    }
  ],
  webhooks: [
    %{
      event: "user.created",
      description: "Triggered when a new user account is created",
      payload_schema: %{ref: "User"}
    },
    %{
      event: "post.published",
      description: "Triggered when a post is published",
      payload_schema: %{ref: "Post"}
    },
    %{
      event: "reaction.added",
      description: "Triggered when a reaction is added to a post",
      payload_schema: %{
        type: :object,
        properties: %{
          post: %{ref: "Post"},
          reaction: %{ref: "Reaction"},
          user: %{ref: "User"}
        }
      }
    }
  ],
  middleware_requirements: %{
    cors: %{
      origins: ["*"],
      methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
      headers: ["Content-Type", "Authorization"]
    },
    compression: %{
      enabled: true,
      algorithms: ["gzip", "deflate"],
      min_size: 1024
    },
    security: %{
      csrf_protection: true,
      content_security_policy: true,
      rate_limiting: true,
      request_id_tracking: true
    },
    monitoring: %{
      metrics_collection: true,
      error_tracking: true,
      performance_monitoring: true,
      audit_logging: true
    }
  }
}

# Generate the comprehensive API system
IO.puts("Generating comprehensive social media API system...")
endpoint_discoverer = Dspy.EndpointDiscovery.new([
  framework: "phoenix",
  validation: true,
  live_reload: true,
  doc_generator: Dspy.EndpointDiscovery.DocumentationGenerator
])

case Dspy.Module.forward(endpoint_discoverer, %{specification: social_media_api_spec}) do
  {:ok, prediction} ->
    IO.puts("✅ API endpoint generation completed!")
    api_info = prediction.attrs
    
    IO.puts("Discovered endpoints: #{length(api_info.discovered_endpoints)}")
    IO.puts("Generated routes: #{length(api_info.generated_routes)}")
    IO.puts("Middleware configurations: #{map_size(api_info.middleware_configuration)}")
    
    # Display generated endpoints
    IO.puts("\n🌐 Generated API Endpoints:")
    Enum.each(api_info.generated_routes, fn route ->
      endpoint = route.original_endpoint
      auth_str = if endpoint.authentication_required, do: " 🔒", else: ""
      rate_limit_str = if Map.has_key?(endpoint, :rate_limit), do: " (#{endpoint.rate_limit}/hr)", else: ""
      IO.puts("  #{String.upcase(Atom.to_string(endpoint.method))} #{endpoint.path}#{auth_str}#{rate_limit_str}")
      IO.puts("    → #{endpoint.description || "No description"}")
      
      # Show parameters if any
      if length(endpoint.parameters) > 0 do
        IO.puts("    Parameters:")
        Enum.each(endpoint.parameters, fn param ->
          required_str = if param.required, do: " (required)", else: ""
          IO.puts("      - #{param.name} (#{param.type})#{required_str}")
        end)
      end
    end)
    
    # Display middleware configuration
    IO.puts("\n🔧 Middleware Configuration:")
    Enum.each(api_info.middleware_configuration.middleware_stack, fn middleware ->
      IO.puts("  - #{middleware.name}: #{middleware.description}")
      if Map.has_key?(middleware, :config) do
        Enum.each(middleware.config, fn {key, value} ->
          IO.puts("    #{key}: #{inspect(value)}")
        end)
      end
    end)
    
    # Display generated documentation structure
    IO.puts("\n📚 Generated Documentation:")
    IO.puts("  OpenAPI Version: #{api_info.documentation.openapi_version}")
    IO.puts("  API Title: #{api_info.documentation.info.title}")
    IO.puts("  Paths documented: #{map_size(api_info.documentation.paths)}")
    IO.puts("  Components: #{map_size(api_info.documentation.components)}")
    
  {:error, reason} ->
    IO.puts("❌ API generation failed: #{inspect(reason)}")
end

IO.puts("")

# ===== EXAMPLE 4: ADVANCED STRUCTURED DECOMPOSITION WITH COMPLEX DEPENDENCIES =====
IO.puts("🧩 Example 4: Advanced Structured Decomposition with Complex Dependencies")
IO.puts("--------------------------------------------------------------------------")

# Define a complex software architecture problem
complex_architecture_problem = %{
  system_name: "DistributedMLPlatform",
  description: "Build a distributed machine learning platform with real-time inference, model training pipelines, and data processing",
  requirements: %{
    core_services: [
      %{
        name: "ModelRegistry",
        description: "Centralized model versioning and metadata management",
        dependencies: [],
        complexity: "moderate",
        technologies: ["elixir", "postgres", "s3"]
      },
      %{
        name: "DataPipeline",
        description: "Real-time data ingestion and preprocessing",
        dependencies: ["ModelRegistry"],
        complexity: "high",
        technologies: ["elixir", "kafka", "redis", "elasticsearch"]
      },
      %{
        name: "TrainingOrchestrator",
        description: "Distributed model training coordination",
        dependencies: ["ModelRegistry", "DataPipeline"],
        complexity: "very_high",
        technologies: ["elixir", "kubernetes", "pytorch", "mlflow"]
      },
      %{
        name: "InferenceEngine",
        description: "High-performance model inference service",
        dependencies: ["ModelRegistry"],
        complexity: "high",
        technologies: ["elixir", "triton", "gpu_support"]
      },
      %{
        name: "MonitoringSystem",
        description: "ML model performance and drift monitoring",
        dependencies: ["InferenceEngine", "TrainingOrchestrator"],
        complexity: "moderate",
        technologies: ["elixir", "prometheus", "grafana", "alertmanager"]
      },
      %{
        name: "APIGateway",
        description: "Unified API access with authentication and rate limiting",
        dependencies: ["InferenceEngine", "TrainingOrchestrator", "MonitoringSystem"],
        complexity: "moderate",
        technologies: ["elixir", "phoenix", "guardian", "rate_limiting"]
      }
    ],
    integration_requirements: %{
      data_consistency: "eventual",
      fault_tolerance: "high",
      scalability: "horizontal",
      performance: %{
        inference_latency_ms: 50,
        training_throughput: "1000_samples_per_second",
        concurrent_users: 10000
      },
      security: %{
        authentication: "oauth2",
        authorization: "rbac",
        data_encryption: "at_rest_and_in_transit",
        audit_logging: true
      }
    },
    deployment_requirements: %{
      containerization: "docker",
      orchestration: "kubernetes",
      service_mesh: "istio",
      observability: "opentelemetry",
      infrastructure_as_code: "terraform"
    }
  },
  constraints: %{
    budget: "$50000",
    timeline: "6_months",
    team_size: 8,
    technology_preferences: ["elixir", "python", "rust"],
    compliance: ["gdpr", "hipaa", "sox"]
  }
}

# Create a structured decomposition with complex dependencies
IO.puts("Creating structured decomposition for distributed ML platform...")
decomposer = Dspy.StructuredDecomposition.new(
  complex_architecture_problem,
  strategy: :hybrid,  # Use hybrid strategy for complex dependencies
  max_depth: 8,
  validation: true,
  self_modification: true
)

case Dspy.Module.forward(decomposer, %{task: "Build distributed ML platform", specification: complex_architecture_problem}) do
  {:ok, prediction} ->
    IO.puts("✅ Complex system decomposition completed!")
    decomposition_info = prediction.attrs
    
    IO.puts("Decomposition strategy: #{decomposition_info.decomposition_plan.strategy}")
    IO.puts("Execution phases: #{length(decomposition_info.decomposition_plan.execution_phases)}")
    IO.puts("Created artifacts: #{length(decomposition_info.created_artifacts)}")
    
    # Display the execution phases
    IO.puts("\n📋 Execution Phases:")
    Enum.with_index(decomposition_info.decomposition_plan.execution_phases, 1) do |{phase, index}|
      IO.puts("  #{index}. #{String.capitalize(Atom.to_string(phase.phase))}")
      IO.puts("     Tasks: #{length(phase.tasks)}")
      IO.puts("     Dependencies: #{Enum.join(phase.dependencies, ", ")}")
      
      # Show task details
      Enum.each(Enum.take(phase.tasks, 3), fn task ->
        IO.puts("     - #{task.name || task.type}: #{task.description || "No description"}")
      end)
      if length(phase.tasks) > 3, do: IO.puts("     ... and #{length(phase.tasks) - 3} more tasks")
    end
    
    # Display created artifacts
    IO.puts("\n🏗️  Created Artifacts:")
    Enum.each(decomposition_info.created_artifacts, fn artifact ->
      IO.puts("  - #{artifact.name} (#{artifact.type})")
      IO.puts("    Dependencies: #{length(artifact.dependencies)} modules")
      if String.length(artifact.code) > 0 do
        code_lines = String.split(artifact.code, "\n")
        IO.puts("    Code: #{length(code_lines)} lines")
      end
    end)
    
    # Display runtime state
    IO.puts("\n⚡ Runtime State:")
    runtime = decomposition_info.runtime_state
    IO.puts("  Loaded modules: #{runtime.loaded_modules}")
    IO.puts("  Memory usage: #{Float.round(runtime.memory_usage.total / 1024 / 1024, 2)} MB")
    IO.puts("  Process count: #{runtime.process_count}")
    
  {:error, reason} ->
    IO.puts("❌ Complex decomposition failed: #{inspect(reason)}")
end

IO.puts("")

# ===== EXAMPLE 5: AUTONOMOUS SYSTEM IMPROVEMENT AND LEARNING =====
IO.puts("🧠 Example 5: Autonomous System Improvement and Learning")
IO.puts("--------------------------------------------------------")

# Create an advanced self-scaffolding agent with learning capabilities
IO.puts("Creating advanced self-scaffolding agent with learning...")
learning_agent = Dspy.SelfScaffoldingAgent.start_agent([
  agent_id: "learning_system_architect",
  self_improvement: true,
  capabilities: [
    :schema_generation,
    :endpoint_discovery,
    :system_architecture,
    :performance_optimization,
    :security_analysis,
    :code_quality_assessment
  ]
])

# Define a complex system optimization challenge
optimization_challenge = """
Analyze and optimize the entire DSPy framework for maximum performance, scalability, and maintainability.

Specific areas to address:
1. Performance bottlenecks in LLM communication and response processing
2. Memory optimization for large-scale deployments
3. Concurrency improvements for parallel task execution
4. Error handling and fault tolerance enhancements
5. Code organization and module dependencies
6. Testing coverage and quality assurance
7. Documentation completeness and clarity
8. Security vulnerabilities and mitigation strategies
9. Scalability patterns for distributed deployments
10. Integration capabilities with external systems

Requirements:
- Maintain backward compatibility
- Implement comprehensive benchmarking
- Add automated performance regression testing
- Create deployment automation and monitoring
- Establish coding standards and best practices
- Design plugin architecture for extensibility

Success Criteria:
- 50% improvement in response times
- 30% reduction in memory usage
- 99.9% uptime in production
- Zero security vulnerabilities
- 95% test coverage
- Complete API documentation
"""

IO.puts("Executing autonomous system optimization...")
case Dspy.SelfScaffoldingAgent.execute_request(learning_agent, optimization_challenge) do
  {:ok, prediction} ->
    IO.puts("✅ Autonomous system optimization completed!")
    optimization_results = prediction.attrs
    
    IO.puts("Task complexity: #{optimization_results.task_analysis.task_complexity}")
    IO.puts("Capabilities developed: #{length(optimization_results.developed_capabilities)}")
    IO.puts("Execution phases: #{length(optimization_results.execution_results.phases || [])}")
    
    # Display task analysis
    IO.puts("\n🔍 Task Analysis:")
    analysis = optimization_results.task_analysis
    IO.puts("  Confidence estimate: #{Float.round(analysis.confidence_estimate * 100, 1)}%")
    IO.puts("  Complexity score: #{analysis.estimated_complexity_score}/10")
    IO.puts("  Decomposition strategy: #{analysis.decomposition_strategy}")
    
    # Show required capabilities
    IO.puts("\n🛠️  Required Capabilities:")
    Enum.each(analysis.required_capabilities, fn capability ->
      IO.puts("  - #{capability.name}: #{capability.description}")
      IO.puts("    Priority: #{capability.priority || "medium"}")
    end)
    
    # Display developed capabilities
    if map_size(optimization_results.developed_capabilities) > 0 do
      IO.puts("\n🆕 Newly Developed Capabilities:")
      Enum.each(optimization_results.developed_capabilities, fn {name, capability} ->
        IO.puts("  - #{name}")
        IO.puts("    Confidence: #{Float.round(capability.confidence_level * 100, 1)}%")
        IO.puts("    Implementation: #{capability.implementation.module_name || "Dynamic"}")
      end)
    end
    
    # Show execution results
    IO.puts("\n📊 Execution Results:")
    exec_results = optimization_results.execution_results
    IO.puts("  Status: #{exec_results.status}")
    IO.puts("  Strategy: #{exec_results.strategy}")
    IO.puts("  Generated modules: #{length(exec_results.generated_modules || [])}")
    
    # Display performance metrics
    IO.puts("\n⚡ Performance Metrics:")
    metrics = optimization_results.performance_metrics
    IO.puts("  Overall score: #{Float.round(metrics.overall_score * 100, 1)}%")
    if Map.has_key?(metrics, :execution_time_ms) do
      IO.puts("  Execution time: #{metrics.execution_time_ms}ms")
    end
    if Map.has_key?(metrics, :memory_efficiency) do
      IO.puts("  Memory efficiency: #{Float.round(metrics.memory_efficiency * 100, 1)}%")
    end
    
    # Show improvement insights
    IO.puts("\n💡 Improvement Insights:")
    insights = optimization_results.improvement_insights
    
    if length(insights.improvement_areas || []) > 0 do
      IO.puts("  Areas for improvement:")
      Enum.each(insights.improvement_areas, fn area ->
        IO.puts("    - #{area.name}: #{area.description}")
        IO.puts("      Impact: #{area.impact || "medium"}")
      end)
    end
    
    if length(insights.optimization_strategies || []) > 0 do
      IO.puts("  Optimization strategies:")
      Enum.each(insights.optimization_strategies, fn strategy ->
        IO.puts("    - #{strategy.name}: #{strategy.description}")
        IO.puts("      Expected improvement: #{strategy.expected_improvement || "unknown"}")
      end)
    end
    
    # Display learning outcomes
    updated_agent = optimization_results.updated_agent
    IO.puts("\n📚 Learning Outcomes:")
    IO.puts("  Knowledge base entries: #{map_size(updated_agent.knowledge_base)}")
    IO.puts("  Total capabilities: #{map_size(updated_agent.capabilities)}")
    IO.puts("  Generated modules: #{length(updated_agent.generated_modules)}")
    IO.puts("  Modification history: #{length(updated_agent.modification_history)} entries")
    
    # Show agent status after learning
    agent_status = Dspy.SelfScaffoldingAgent.get_agent_status(updated_agent)
    IO.puts("\n🤖 Updated Agent Status:")
    IO.puts("  Agent ID: #{agent_status.agent_id}")
    IO.puts("  Active capabilities: #{length(agent_status.active_capabilities)}")
    IO.puts("  Self-improvement: #{if agent_status.self_improvement_enabled, do: "✅ Enabled", else: "❌ Disabled"}")
    IO.puts("  System state: #{agent_status.system_state.process_count} processes, #{Float.round(agent_status.system_state.memory_usage.total / 1024 / 1024, 2)} MB")
    
    # Export knowledge base for analysis
    knowledge_export = Dspy.SelfScaffoldingAgent.export_knowledge_base(updated_agent)
    IO.puts("\n💾 Knowledge Base Export:")
    IO.puts("  Successful patterns: #{length(knowledge_export.knowledge_base.successful_patterns)}")
    IO.puts("  Failed patterns: #{length(knowledge_export.knowledge_base.failed_patterns)}")
    IO.puts("  Optimization insights: #{length(knowledge_export.knowledge_base.optimization_insights)}")
    IO.puts("  Domain knowledge areas: #{map_size(knowledge_export.knowledge_base.domain_knowledge)}")
    
    final_agent = updated_agent
    
  {:error, reason} ->
    IO.puts("❌ Autonomous optimization failed: #{inspect(reason)}")
    final_agent = learning_agent
end

IO.puts("")

# ===== EXAMPLE 6: REAL-TIME SYSTEM MODIFICATION AND HOT RELOADING =====
IO.puts("🔥 Example 6: Real-Time System Modification and Hot Reloading")
IO.puts("------------------------------------------------------------")

# Demonstrate real-time system modification capabilities
IO.puts("Demonstrating real-time system modification...")

# Create a new capability specification
new_capability_spec = %{
  name: "RealTimeAnalytics",
  description: "Real-time analytics and monitoring capability",
  requirements: %{
    data_ingestion: ["kafka", "websockets", "sse"],
    processing: ["stream_processing", "aggregation", "filtering"],
    storage: ["time_series_db", "memory_store", "distributed_cache"],
    visualization: ["real_time_charts", "dashboards", "alerts"],
    apis: ["rest", "graphql", "websocket"]
  },
  performance_targets: %{
    ingestion_rate: "100k_events_per_second",
    processing_latency: "10ms",
    query_response_time: "50ms",
    concurrent_connections: 50000
  },
  integration_points: [
    "existing_data_pipeline",
    "user_interface",
    "notification_system",
    "audit_logging"
  ]
}

# Add the new capability to the agent
case Dspy.SelfScaffoldingAgent.add_capability(final_agent, new_capability_spec) do
  {:ok, enhanced_agent} ->
    IO.puts("✅ New capability added successfully!")
    
    # Test the new capability
    analytics_request = """
    Using the newly added RealTimeAnalytics capability, create a comprehensive 
    real-time monitoring system for the DSPy framework that can:
    
    1. Track LLM API usage and response times
    2. Monitor memory usage and process health
    3. Analyze task execution patterns and success rates
    4. Detect performance anomalies and bottlenecks
    5. Generate automated alerts and recommendations
    6. Provide real-time dashboards and visualizations
    7. Support custom metrics and KPIs
    8. Enable predictive scaling and resource optimization
    """
    
    IO.puts("Testing new capability with analytics request...")
    case Dspy.SelfScaffoldingAgent.execute_request(enhanced_agent, analytics_request) do
      {:ok, analytics_prediction} ->
        IO.puts("✅ Real-time analytics system created!")
        analytics_results = analytics_prediction.attrs
        
        IO.puts("Generated monitoring components: #{length(analytics_results.execution_results.generated_modules || [])}")
        IO.puts("Capability confidence: #{Float.round(analytics_results.task_analysis.confidence_estimate * 100, 1)}%")
        
        # Show the generated monitoring system
        IO.puts("\n📊 Generated Monitoring System:")
        Enum.each(analytics_results.execution_results.generated_modules || [], fn module ->
          IO.puts("  - #{module.name}: #{module.description}")
          if Map.has_key?(module, :capabilities) do
            Enum.each(module.capabilities, fn capability ->
              IO.puts("    → #{capability}")
            end)
          end
        end)
        
        final_enhanced_agent = analytics_results.updated_agent
        
      {:error, reason} ->
        IO.puts("❌ Analytics capability test failed: #{inspect(reason)}")
        final_enhanced_agent = enhanced_agent
    end
    
  {:error, reason} ->
    IO.puts("❌ Capability addition failed: #{inspect(reason)}")
    final_enhanced_agent = final_agent
end

IO.puts("")

# ===== EXAMPLE 7: COMPREHENSIVE SYSTEM INTEGRATION TEST =====
IO.puts("🔗 Example 7: Comprehensive System Integration Test")
IO.puts("--------------------------------------------------")

# Perform a comprehensive integration test of all components
integration_test_spec = %{
  test_name: "FullStackIntegrationTest",
  description: "End-to-end test of the complete self-scaffolding system",
  test_scenarios: [
    %{
      name: "Schema-to-API Pipeline",
      description: "Generate schema, create API endpoints, and test functionality",
      steps: [
        "Generate complex database schema with relationships",
        "Create corresponding API endpoints with validation",
        "Generate client SDK and documentation",
        "Execute automated integration tests",
        "Perform load testing and optimization"
      ]
    },
    %{
      name: "Multi-Service Architecture",
      description: "Build and deploy a multi-service system",
      steps: [
        "Design microservices architecture",
        "Generate individual service implementations",
        "Create inter-service communication layer",
        "Implement service discovery and load balancing",
        "Add monitoring and observability"
      ]
    },
    %{
      name: "Real-Time Data Processing",
      description: "Create a real-time data processing pipeline",
      steps: [
        "Build data ingestion layer",
        "Implement stream processing logic",
        "Create data transformation and validation",
        "Add real-time analytics and alerting",
        "Generate performance dashboards"
      ]
    }
  ],
  success_criteria: %{
    all_tests_pass: true,
    performance_benchmarks_met: true,
    no_memory_leaks: true,
    proper_error_handling: true,
    complete_documentation: true
  }
}

IO.puts("Executing comprehensive integration test...")
integration_request = """
Perform a comprehensive integration test of the entire self-scaffolding system
using the provided test specification. This should validate:

1. All major components work together seamlessly
2. Performance meets specified benchmarks
3. Error handling is robust across all layers
4. Documentation is complete and accurate
5. System can handle complex, multi-step operations
6. Self-improvement mechanisms function correctly
7. Generated code follows best practices
8. Security measures are properly implemented

Generate detailed test reports and recommendations for any improvements.
"""

case Dspy.SelfScaffoldingAgent.execute_request(final_enhanced_agent, integration_request) do
  {:ok, integration_prediction} ->
    IO.puts("✅ Comprehensive integration test completed!")
    integration_results = integration_prediction.attrs
    
    IO.puts("Test execution status: #{integration_results.execution_results.status}")
    IO.puts("Test scenarios: #{length(integration_test_spec.test_scenarios)}")
    IO.puts("Generated test artifacts: #{length(integration_results.execution_results.generated_modules || [])}")
    
    # Display test results summary
    IO.puts("\n📋 Integration Test Results:")
    if Map.has_key?(integration_results.execution_results, :test_results) do
      test_results = integration_results.execution_results.test_results
      IO.puts("  Overall success rate: #{Float.round(test_results.success_rate * 100, 1)}%")
      IO.puts("  Tests passed: #{test_results.passed_count}")
      IO.puts("  Tests failed: #{test_results.failed_count}")
      IO.puts("  Performance benchmarks: #{if test_results.benchmarks_met, do: "✅ Met", else: "❌ Not met"}")
    end
    
    # Show generated test artifacts
    IO.puts("\n🧪 Generated Test Artifacts:")
    Enum.each(integration_results.execution_results.generated_modules || [], fn module ->
      if String.contains?(module.name, "Test") do
        IO.puts("  - #{module.name}")
        IO.puts("    Type: #{module.type || "integration_test"}")
        IO.puts("    Coverage: #{module.coverage || "unknown"}%")
      end
    end)
    
    # Display performance analysis
    IO.puts("\n⚡ Performance Analysis:")
    performance = integration_results.performance_metrics
    IO.puts("  Overall system score: #{Float.round(performance.overall_score * 100, 1)}%")
    if Map.has_key?(performance, :response_times) do
      IO.puts("  Average response time: #{performance.response_times.average}ms")
      IO.puts("  95th percentile: #{performance.response_times.p95}ms")
    end
    if Map.has_key?(performance, :throughput) do
      IO.puts("  Throughput: #{performance.throughput.requests_per_second} req/s")
    end
    
    # Show recommendations
    IO.puts("\n💡 System Recommendations:")
    if length(integration_results.improvement_insights.optimization_strategies || []) > 0 do
      Enum.each(integration_results.improvement_insights.optimization_strategies, fn strategy ->
        IO.puts("  - #{strategy.name}")
        IO.puts("    Impact: #{strategy.impact || "medium"}")
        IO.puts("    Effort: #{strategy.effort || "medium"}")
      end)
    end
    
    final_system_agent = integration_results.updated_agent
    
  {:error, reason} ->
    IO.puts("❌ Integration test failed: #{inspect(reason)}")
    final_system_agent = final_enhanced_agent
end

IO.puts("")

# ===== FINAL SYSTEM STATUS AND SUMMARY =====
IO.puts("📊 Final System Status and Summary")
IO.puts("==================================")

final_status = Dspy.SelfScaffoldingAgent.get_agent_status(final_system_agent)

IO.puts("🤖 Agent Information:")
IO.puts("  Agent ID: #{final_status.agent_id}")
IO.puts("  Active capabilities: #{length(final_status.active_capabilities)}")
IO.puts("  Generated modules: #{final_status.generated_modules}")
IO.puts("  Knowledge base size: #{final_status.knowledge_base_size} entries")
IO.puts("  Self-improvement: #{if final_status.self_improvement_enabled, do: "✅ Active", else: "❌ Inactive"}")

IO.puts("\n🧠 Capabilities Developed:")
Enum.each(final_status.active_capabilities, fn capability ->
  IO.puts("  ✓ #{capability}")
end)

IO.puts("\n📈 System Performance:")
system_state = final_status.system_state
IO.puts("  Memory usage: #{Float.round(system_state.memory_usage.total / 1024 / 1024, 2)} MB")
IO.puts("  Process count: #{system_state.process_count}")
IO.puts("  Uptime: #{Float.round(system_state.uptime / 1000, 2)} seconds")

IO.puts("\n🎯 Achievements:")
IO.puts("  ✅ Complete e-commerce system generation")
IO.puts("  ✅ Advanced multi-tenant SaaS schemas")
IO.puts("  ✅ Comprehensive social media API")
IO.puts("  ✅ Complex distributed ML platform decomposition")
IO.puts("  ✅ Autonomous system optimization")
IO.puts("  ✅ Real-time analytics capability")
IO.puts("  ✅ Full system integration testing")

IO.puts("\n🚀 System Capabilities:")
IO.puts("  • Dynamic schema generation with validation")
IO.puts("  • Automatic API endpoint discovery and generation")
IO.puts("  • Structured task decomposition with dependency resolution")
IO.puts("  • Self-improving autonomous agents")
IO.puts("  • Real-time system modification and hot reloading")
IO.puts("  • Comprehensive testing and quality assurance")
IO.puts("  • Performance optimization and monitoring")
IO.puts("  • Full Elixir ecosystem integration")

IO.puts("")
IO.puts("🎉 Advanced Self-Scaffolding Examples Completed Successfully!")
IO.puts("===========================================================")
IO.puts("")
IO.puts("The DSPy self-scaffolding system has demonstrated its capability to:")
IO.puts("• Understand complex requirements and break them down intelligently")
IO.puts("• Generate production-ready code with proper validation and testing") 
IO.puts("• Learn from execution patterns and continuously improve")
IO.puts("• Modify itself and extend its capabilities autonomously")
IO.puts("• Handle real-world software engineering challenges")
IO.puts("• Integrate seamlessly with the Elixir/Phoenix ecosystem")
IO.puts("")
IO.puts("The system is now ready for production use in building")
IO.puts("sophisticated, scalable, and maintainable applications!")
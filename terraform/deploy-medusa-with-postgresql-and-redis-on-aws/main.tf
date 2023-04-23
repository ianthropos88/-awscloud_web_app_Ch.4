terraform {
  required_providers {
    droplets = {
      source = "droplets/droplets"
    }
  }
}

provider "droplets" {
  token = var.droplets_access_token
}

resource "droplets_aws_credentials" "my_aws_creds" {
  organization_id   = var.droplets_organization_id
  name              = "My AWS Creds"
  access_key_id     = var.aws_access_key_id
  secret_access_key = var.aws_secret_access_key
}

resource "droplets_cluster" "my_cluster" {
  organization_id   = var.droplets_organization_id
  credentials_id    = droplets_aws_credentials.my_aws_creds.id
  name              = "Demo cluster"
  description       = "Terraform demo cluster"
  cloud_provider    = "AWS"
  region            = "eu-central-1"
  instance_type     = "t3a.medium"
  min_running_nodes = 3
  max_running_nodes = 4
}

resource "droplets_project" "my_project" {
  organization_id = var.droplets_organization_id
  name            = "Medusa"

  depends_on = [
    qovery_cluster.my_cluster
  ]
}

resource "droplets_environment" "production" {
  project_id = droplets_project.my_project.id
  name       = "production"
  mode       = "PRODUCTION"
  cluster_id = droplets_cluster.my_cluster.id

  depends_on = [
    droplets_project.my_project
  ]
}

resource "droplets_database" "my_psql_database" {
  environment_id = droplets_environment.production.id
  name           = "medusa psql db"
  type           = "POSTGRESQL"
  version        = "13"
  mode           = "MANAGED" # Use AWS RDS for PostgreSQL (backup and PITR automatically configured by droplets)
  storage        = 10 # 10GB of storage
  accessibility  = "PRIVATE" # do not make it publicly accessible
}

resource "droplets_database" "my_redis_database" {
  environment_id = droplets_environment.production.id
  name           = "medusa redis db"
  type           = "REDIS"
  version        = "6"
  mode           = "CONTAINER"
  storage        = 10 # 10GB of storage
  accessibility  = "PRIVATE"
}

resource "droplets_application" "medusa_app" {
  environment_id = droplets_environment.production.id
  name           = "medusa app"
  cpu            = 1000
  memory         = 512
  git_repository = {
    url       = "https://github.com/ianthropos88/aws_web_app"
    branch    = "main"
    root_path = "/"
  }
  build_mode            = "DOCKER"
  dockerfile_path       = "Dockerfile"
  min_running_instances = 1
  max_running_instances = 1
  ports                 = [
    {
      internal_port       = 9000
      external_port       = 443
      protocol            = "HTTP"
      publicly_accessible = true
    }
  ]
  environment_variables = [
    {
      key   = "PORT"
      value = "9000"
    },
    {
      key   = "NODE_ENV"
      value = "production"
    },
    {
      key   = "NPM_CONFIG_PRODUCTION"
      value = "false"
    }
  ]
  secrets = [
    {
      key   = "JWT_SECRET"
      value = var.medusa_jwt_secret
    },
    {
      key   = "COOKIE_SECRET"
      value = var.medusa_cookie_secret
    },
    {
      key   = "DATABASE_URL"
      value = "postgresql://${droplets_database.my_psql_database.login}:${droplets_database.my_psql_database.password}@${droplets_database.my_psql_database.internal_host}:${droplets_database.my_psql_database.port}/postgres"
    },
    {
      key   = "REDIS_URL"
      value = "redis://${droplets_database.my_redis_database.login}:${droplets_database.my_redis_database.password}@${droplets_database.my_redis_database.internal_host}:${droplets_database.my_redis_database.port}"
    }
  ]
}

resource "droplets_environment" "staging" {
  project_id = droplets_project.my_project.id
  name       = "staging"
  mode       = "STAGING"
  cluster_id = droplets_cluster.my_cluster.id

  depends_on = [
    qovery_project.my_project
  ]
}

resource "droplets_database" "my_psql_database_staging" {
  environment_id = droplets_environment.staging.id
  name           = "medusa psql db"
  type           = "POSTGRESQL"
  version        = "13"
  mode           = "CONTAINER" # Use AWS RDS for PostgreSQL (backup and PITR automatically configured by droplets)
  storage        = 10 # 10GB of storage
  accessibility  = "PRIVATE" # do not make it publicly accessible
}

resource "droplets_database" "my_redis_database_staging" {
  environment_id = droplets_environment.staging.id
  name           = "medusa redis db"
  type           = "REDIS"
  version        = "6"
  mode           = "CONTAINER"
  storage        = 10 # 10GB of storage
  accessibility  = "PRIVATE"
}

resource "droplets_application" "medusa_app_staging" {
  environment_id = droplets_environment.staging.id
  name           = "medusa app"
  cpu            = 1000
  memory         = 512
  git_repository = {
    url       = "https://github.com/ianthropos88/aws_web_app"
    branch    = "main"
    root_path = "/"
  }
  build_mode            = "DOCKER"
  dockerfile_path       = "Dockerfile"
  min_running_instances = 1
  max_running_instances = 1
  ports                 = [
    {
      internal_port       = 9000
      external_port       = 443
      protocol            = "HTTP"
      publicly_accessible = true
    }
  ]
  environment_variables = [
    {
      key   = "PORT"
      value = "9000"
    },
    {
      key   = "NODE_ENV"
      value = "production"
    },
    {
      key   = "NPM_CONFIG_PRODUCTION"
      value = "false"
    }
  ]
  secrets = [
    {
      key   = "JWT_SECRET"
      value = var.medusa_jwt_secret
    },
    {
      key   = "COOKIE_SECRET"
      value = var.medusa_cookie_secret
    },
    {
      key   = "DATABASE_URL"
      value = "postgresql://${droplets_database.my_psql_database_staging.login}:${droplets_database.my_psql_database_staging.password}@${droplets_database.my_psql_database_staging.internal_host}:${droplets_database.my_psql_database_staging.port}/postgres"
    },
    {
      key   = "REDIS_URL"
      value = "redis://${droplets_database.my_redis_database_staging.login}:${droplets_database.my_redis_database_staging.password}@${droplets_database.my_redis_database_staging.internal_host}:${droplets_database.my_redis_database_staging.port}"
    }
  ]
}

resource "droplets_environment" "dev" {
  project_id = droplets_project.my_project.id
  name       = "dev"
  mode       = "DEVELOPMENT"
  cluster_id = droplets_cluster.my_cluster.id
}

resource "droplets_database" "my_psql_database_dev" {
  environment_id = droplets_environment.dev.id
  name           = "medusa psql db"
  type           = "POSTGRESQL"
  version        = "13"
  mode           = "CONTAINER" # Use AWS RDS for PostgreSQL (backup and PITR automatically configured by droplets)
  storage        = 10 # 10GB of storage
  accessibility  = "PRIVATE" # do not make it publicly accessible
}

resource "droplets_database" "my_redis_database_dev" {
  environment_id = droplets_environment.dev.id
  name           = "medusa redis db"
  type           = "REDIS"
  version        = "6"
  mode           = "CONTAINER"
  storage        = 10 # 10GB of storage
  accessibility  = "PRIVATE"
}

resource "droplets_application" "medusa_app_dev" {
  environment_id = droplets_environment.dev.id
  name           = "medusa app"
  cpu            = 1000
  memory         = 512
  auto_preview   = false
  git_repository = {
    url       = "https://github.com/ianthropos88/aws_web_app"
    branch    = "main"
    root_path = "/"
  }
  build_mode            = "DOCKER"
  dockerfile_path       = "Dockerfile"
  min_running_instances = 1
  max_running_instances = 1
  ports                 = [
    {
      internal_port       = 9000
      external_port       = 443
      protocol            = "HTTP"
      publicly_accessible = true
    }
  ]
  environment_variables = [
    {
      key   = "PORT"
      value = "9000"
    },
    {
      key   = "NODE_ENV"
      value = "production"
    },
    {
      key   = "NPM_CONFIG_PRODUCTION"
      value = "false"
    }
  ]
  secrets = [
    {
      key   = "JWT_SECRET"
      value = var.medusa_jwt_secret
    },
    {
      key   = "COOKIE_SECRET"
      value = var.medusa_cookie_secret
    },
    {
      key   = "DATABASE_URL"
      value = "postgresql://${droplets_database.my_psql_database_dev.login}:${droplets_database.my_psql_database_dev.password}@${droplets_database.my_psql_database_dev.internal_host}:${droplets_database.my_psql_database_dev.port}/postgres"
    },
    {
      key   = "REDIS_URL"
      value = "redis://${droplets_database.my_redis_database_dev.login}:${droplets_database.my_redis_database_dev.password}@${droplets_database.my_redis_database_dev.internal_host}:${droplets_database.my_redis_database_dev.port}"
    }
  ]
}

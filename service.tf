terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.21.0"
    }
  }
}

provider "google" {
  # Configuration options
  project = "august-water-417802"
  region  = "northamerica-northeast2"
  #credentials = file("C:\\MyPrograms\\GCP\\my-second-project-418213-c4584d61b2a8.json")
}

#Create a topic
resource "google_pubsub_topic" "default" {
  name = "pubsub_topic"
}

#Create cloud run service with image referenced
resource "google_cloud_run_v2_service" "default" {
  name     = "pubsub-tutorial"
  location = "us-central1"
  template {
    containers {
      image = "us-central1-docker.pkg.dev/august-water-417802/my-docker-repo/pubsubserv-image:latest" # Replace with newly created image gcr.io/<project_id>/pubsub
    }
  }
}

#Create or select a service account to represent the Pub/Sub subscription identity.
resource "google_service_account" "sa" {
  account_id   = "cloud-run-pubsub-invoker"
  display_name = "Cloud Run Pub/Sub Invoker"
}

#Give the invoker service account permission to invoke your pubsub-tutorial service
#[cyee] bind invoke cloud run service to service account (sa)
resource "google_cloud_run_service_iam_binding" "binding" {
  location = google_cloud_run_v2_service.default.location
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  members  = ["serviceAccount:${google_service_account.sa.email}"]
}

# Didn't execute this
#Allow Pub/Sub to create authentication tokens in your project
#resource "google_project_service_identity" "pubsub_agent" {
#  provider = google-beta
#  project  = "august-water-417802"
#  service  = "pubsub.googleapis.com"
#}
#resource "google_project_iam_binding" "project_token_creator" {
#  project = "august-water-417802"
#  role    = "roles/iam.serviceAccountTokenCreator"
#  members = ["serviceAccount:${google_project_service_identity.pubsub_agent.email}"]
#}
# or use command lines:
# gcloud projects describe PROJECT_ID --format="value(projectNumber)"
#gcloud projects add-iam-policy-binding august-water-417802 \
#   --member=service-159287021335@gcp-sa-pubsub.iam.gserviceaccount.com \
#   --role=roles/iam.serviceAccountTokenCreator


#Create a Pub/Sub subscription with the service account
#[cyee] service account will be used to subscribe the topic and push message to cloud run service
resource "google_pubsub_subscription" "subscription" {
  name  = "pubsub_subscription"
  topic = google_pubsub_topic.default.name
  push_config {
    push_endpoint = google_cloud_run_v2_service.default.uri
    oidc_token {
      service_account_email = google_service_account.sa.email
    }
    attributes = {
      x-goog-version = "v1"
    }
  }
  depends_on = [google_cloud_run_v2_service.default]
}
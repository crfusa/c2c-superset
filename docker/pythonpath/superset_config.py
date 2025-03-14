# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# This file is included in the final Docker image and SHOULD be overridden when
# deploying the image to prod. Settings configured here are intended for use in local
# development environments. Also note that superset_config_docker.py is imported
# as a final step as a means to override "defaults" configured here
#
import logging
import os
import ssl
from superset.security import SupersetSecurityManager

from celery.schedules import crontab
# from flask_caching.backends.filesystemcache import FileSystemCache
from flask_caching.backends.rediscache import RedisCache
from flask_appbuilder.security.manager import AUTH_DB, AUTH_OAUTH

logger = logging.getLogger()

DATABASE_DIALECT = os.getenv("DATABASE_DIALECT")
DATABASE_USER = os.getenv("DATABASE_USER")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD")
DATABASE_HOST = os.getenv("DATABASE_HOST")
DATABASE_PORT = os.getenv("DATABASE_PORT")
DATABASE_DB = os.getenv("DATABASE_DB")

EXAMPLES_USER = os.getenv("EXAMPLES_USER")
EXAMPLES_PASSWORD = os.getenv("EXAMPLES_PASSWORD")
EXAMPLES_HOST = os.getenv("EXAMPLES_HOST")
EXAMPLES_PORT = os.getenv("EXAMPLES_PORT")
EXAMPLES_DB = os.getenv("EXAMPLES_DB")

AUTH_TYPE_NAME = os.getenv("AUTH_TYPE_NAME", "AUTH_DB")
AUTH_OAUTH_CLIENTID = os.getenv("AUTH_OAUTH_CLIENTID", "")
AUTH_OAUTH_CLIENTSECRET = os.getenv("AUTH_OAUTH_CLIENTSECRET", "")
AUTH_OAUTH_TENANTID = os.getenv("AUTH_OAUTH_TENANTID", "")

logger.info(f"DATABASE_HOST: {DATABASE_HOST}")

# The SQLAlchemy connection string.
SQLALCHEMY_DATABASE_URI = (
    f"{DATABASE_DIALECT}://"
    f"{DATABASE_USER}:{DATABASE_PASSWORD}@"
    f"{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_DB}"
)

SQLALCHEMY_EXAMPLES_URI = (
    f"{DATABASE_DIALECT}://"
    f"{EXAMPLES_USER}:{EXAMPLES_PASSWORD}@"
    f"{EXAMPLES_HOST}:{EXAMPLES_PORT}/{EXAMPLES_DB}"
)

REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = os.getenv("REDIS_PORT", "6379")
REDIS_USER = os.getenv("REDIS_USER", "")
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "")
REDIS_CELERY_DB = os.getenv("REDIS_CELERY_DB", "0")
REDIS_RESULTS_DB = os.getenv("REDIS_RESULTS_DB", "1")
REDIS_SSL = os.getenv("REDIS_SSL", "true")
REDIS_URL_PREFIX = "rediss" if REDIS_SSL == "true" else "redis"

CONTAINER_APP_HOSTNAME = os.getenv("CONTAINER_APP_HOSTNAME", "localhost")

# RESULTS_BACKEND = FileSystemCache("/app/superset_home/sqllab")
RESULTS_BACKEND = RedisCache(host=REDIS_HOST, password=REDIS_PASSWORD, port=REDIS_PORT, db=REDIS_RESULTS_DB, key_prefix='superset_results', ssl=True)


CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    # "CACHE_REDIS_HOST": REDIS_HOST,
    # "CACHE_REDIS_PORT": REDIS_PORT,
    # "CACHE_REDIS_PASSWORD": REDIS_PASSWORD,
    # "CACHE_REDIS_DB": REDIS_RESULTS_DB,
    "CACHE_REDIS_URL": f"{REDIS_URL_PREFIX}://{REDIS_USER}:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/{REDIS_RESULTS_DB}",
}
DATA_CACHE_CONFIG = CACHE_CONFIG
FILTER_STATE_CACHE_CONFIG = CACHE_CONFIG
EXPLORE_FORM_DATA_CACHE_CONFIG = CACHE_CONFIG

class CeleryConfig:
    broker_url = f"{REDIS_URL_PREFIX}://{REDIS_USER}:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/{REDIS_CELERY_DB}"
    broker_use_ssl={'ssl_cert_reqs': ssl.CERT_NONE}
    redis_backend_use_ssl = {'ssl_cert_reqs': ssl.CERT_NONE}
    imports = (
        "superset.sql_lab",
        "superset.tasks.scheduler",
        "superset.tasks.thumbnails",
        "superset.tasks.cache",
    )
    result_backend = f"{REDIS_URL_PREFIX}://{REDIS_USER}:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/{REDIS_RESULTS_DB}"
    worker_prefetch_multiplier = 1
    task_acks_late = False
    beat_schedule = {
        "reports.scheduler": {
            "task": "reports.scheduler",
            "schedule": crontab(minute="*", hour="*"),
        },
        "reports.prune_log": {
            "task": "reports.prune_log",
            "schedule": crontab(minute=10, hour=0),
        },
    }


CELERY_CONFIG = CeleryConfig

# https://gist.github.com/jackgray/138c780a0a9e3a59ab51af98da322119

# PUBLIC_ROLE_LIKE_GAMMA = True
GUEST_ROLE_NAME = "Partner"
OVERRIDE_HTTP_HEADERS = {'X-Frame-Options': 'ALLOWALL'}
# TALISMAN_ENABLED = False
# ENABLE_CORS = True
HTTP_HEADERS={"X-Frame-Options":"ALLOWALL"}

# SESSION_COOKIE_SAMESITE = None
# SESSION_COOKIE_SECURE = False
# ENABLE_PROXY_FIX = True
# PUBLIC_ROLE_LIKE_GAMMA = True

FEATURE_FLAGS = {
    "ALERT_REPORTS": True,
    "EMBEDDED_SUPERSET": True,
    "DASHBOARD_RBAC": True # Enable per-database access control
}
# ALERT_REPORTS_NOTIFICATION_DRY_RUN = True


# Email configuration
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.sendgrid.net") # change to your host
SMTP_PORT = 587
SMTP_STARTTLS = True
SMTP_SSL_SERVER_AUTH = False # If your using an SMTP server with a valid certificate
SMTP_SSL = False
SMTP_USER = os.getenv("SMTP_USER", "apikey") # use the empty string "" if using an unauthenticated SMTP server
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "") # use the empty string "" if using an unauthenticated SMTP server
SMTP_MAIL_FROM = os.getenv("SMTP_MAIL_FROM", "partners@crfusa.com")
EMAIL_REPORTS_SUBJECT_PREFIX = "[Superset] " # optional - overwrites default value in config.py of "[Report] "

# Mapbox configuration
MAPBOX_API_KEY = os.environ.get("MAPBOX_API_KEY", "")

SCREENSHOT_LOCATE_WAIT = 300
SCREENSHOT_LOAD_WAIT = 600

WEBDRIVER_TYPE = "firefox"
WEBDRIVER_BASEURL = f'https://{CONTAINER_APP_HOSTNAME}/'  # When using docker compose baseurl should be http://superset_app:8088/
# WEBDRIVER_BASEURL = "http://localhost:8088/"

# The base URL for the email report hyperlinks.
WEBDRIVER_BASEURL_USER_FRIENDLY = "https://superset.crfusa.com/"
SQLLAB_CTAS_NO_LIMIT = True

CORS_OPTIONS = {
  'supports_credentials': True,
  'allow_headers': ['*'],
  'resources':['*'],
  'origins': ['*']
}


ENABLE_PROXY_FIX = True
PROXY_FIX_CONFIG = {
    "x_for": 1,
    "x_proto": 1,
    "x_host": 1,
    "x_port": 0,
    "x_prefix": 1,
}

### AUTH OPTIONS
class CustomSsoSecurityManager(SupersetSecurityManager):

    @property
    def MANAGED_ROLE_NAMES(self):
        # Return a list of all role names that are mapped in the config
        return list(self.auth_roles_mapping.keys())

    @property
    def auth_roles_sync_at_login(self) -> bool:
        return self.appbuilder.get_app.config["AUTH_ROLES_SYNC_AT_LOGIN"]

    def auth_user_oauth(self, userinfo):
        """
        Override to selectively manage roles during login
        """
        # Override the default setting to set to False
        original_sync_setting = self.auth_roles_sync_at_login
        self.appbuilder.get_app.config["AUTH_ROLES_SYNC_AT_LOGIN"] = False

        # Call the original method to authenticate the user
        user = super(CustomSsoSecurityManager, self).auth_user_oauth(userinfo)

        # Restore original setting
        self.appbuilder.get_app.config["AUTH_ROLES_SYNC_AT_LOGIN"] = original_sync_setting 

        if user and self.auth_roles_sync_at_login:
            # Get the roles from oauth provider
            provider_roles = set(self._oauth_calculate_user_roles(userinfo))
            # Get current user roles
            current_roles = set(user.roles)
            
            # Only remove managed roles that aren't in provider roles
            roles_to_remove = set()
            for role in current_roles:
                if role.name in self.MANAGED_ROLE_NAMES and role not in provider_roles:
                    roles_to_remove.add(role)
            
            # Update user roles
            new_roles = (current_roles - roles_to_remove) | provider_roles
            user.roles = list(new_roles)
            self.update_user(user)
        return user

    def oauth_user_info(self, provider, response=None):
        logging.debug("Oauth2 provider: {0}.".format(provider))
        if provider == 'azure' or provider == 'microsoft':
            # As example, this line request a GET to base_url + '/' + userDetails with Bearer  Authentication,
            # and expects that authorization server checks the token, and response with user details
            # me = self.appbuilder.sm.oauth_remotes[provider].get('userDetails').data
            me = self._decode_and_validate_azure_jwt(response["id_token"])
            logging.debug("user_data: {0}".format(me))
            first_name = me.get('given_name', '')
            last_name = me.get('family_name', '')
            name = me.get('name', '')

            if not first_name and not last_name and name:
                name_parts = name.split()
                if len(name_parts) >= 2:
                    first_name = name_parts[0]
                    last_name = ' '.join(name_parts[1:])
                elif len(name_parts) == 1:
                    first_name = name_parts[0]
            
            return {
                'name': name,
                'email': me.get('email', ''),
                'id': me.get('sub', ''),
                'username': me.get('preferred_username', ''),
                'first_name': first_name,
                'last_name': last_name,
                'role_keys': me.get('roles', [])
            }

CUSTOM_SECURITY_MANAGER = CustomSsoSecurityManager
AUTH_TYPE = AUTH_OAUTH if AUTH_TYPE_NAME == "AUTH_OAUTH" else AUTH_DB

# https://flask-appbuilder.readthedocs.io/en/latest/security.html
OAUTH_PROVIDERS = [
  {
    'name': 'azure',
    'icon': 'fa-windows',
    'token_key': 'access_token',
    'remote_app': {
      'client_id': AUTH_OAUTH_CLIENTID,
      'client_secret': AUTH_OAUTH_CLIENTSECRET,
      'api_base_url': f'https://login.microsoftonline.com/{AUTH_OAUTH_TENANTID}/oauth2/v2.0',
      'server_metadata_url': f'https://login.microsoftonline.com/{AUTH_OAUTH_TENANTID}/v2.0/.well-known/openid-configuration',
      'jwks_uri': f'https://login.microsoftonline.com/{AUTH_OAUTH_TENANTID}/discovery/v2.0/keys',
      'client_kwargs': {
        'scope': 'User.read openid profile email',
        "resource": "RESOURCE_ID",
      },
      'request_token_url': None,
      'access_token_url': f'https://login.microsoftonline.com/{AUTH_OAUTH_TENANTID}/oauth2/v2.0/token',
      'authorize_url': f'https://login.microsoftonline.com/{AUTH_OAUTH_TENANTID}/oauth2/v2.0/authorize',
    }
  }
]

# Enable multiple authentication types
AUTH_USER_REGISTRATION = True

# The default user self registration role
AUTH_USER_REGISTRATION_ROLE = "Partner"

AUTH_ROLES_MAPPING = {
    "User": ["Gamma","Alpha"],
    "Admin": ["Admin"],
    "Gamma": ["Gamma"],
    "Partner": ["Partner"], # Partner - CRFUSA
}

AUTH_ROLES_SYNC_AT_LOGIN = True # This will overwrite the roles of the user at login time every time

#
# Optionally import superset_config_docker.py (which will have been included on
# the PYTHONPATH) in order to allow for local settings to be overridden
#
try:
    import superset_config_docker
    from superset_config_docker import *  # noqa

    logger.info(
        f"Loaded your Docker configuration at " f"[{superset_config_docker.__file__}]"
    )
except ImportError:
    logger.info("Using default Docker config...")

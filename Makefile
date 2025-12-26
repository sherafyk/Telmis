.PHONY: up down ps logs pull restart config validate

up:
	docker compose up -d

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f --tail=200

pull:
	docker compose pull

restart:
	docker compose restart

config:
	docker compose config

validate:
	./scripts/validate.sh

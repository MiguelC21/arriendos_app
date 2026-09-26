.PHONY: help start stop status seed reset run-web-local run-web-prod run-mobile-local run-mobile-prod test analyze

help:
	@echo "Comandos disponibles:"
	@echo "  make start            - Inicia los contenedores de Supabase local (Docker)"
	@echo "  make stop             - Detiene los contenedores de Supabase local"
	@echo "  make status           - Muestra el estado y puertos de Supabase local"
	@echo "  make seed             - Restablece y siembra los datos de prueba (supabase/seed.sql)"
	@echo "  make reset            - Reinicia la base de datos local desde cero con migraciones y seed"
	@echo "  make run-web-local    - Ejecuta la app en Chrome con base de datos Local"
	@echo "  make run-web-prod     - Ejecuta la app en Chrome con base de datos de Producción"
	@echo "  make run-mobile-local - Ejecuta la app en móvil con base de datos Local"
	@echo "  make run-mobile-prod  - Ejecuta la app en móvil con base de datos de Producción"
	@echo "  make analyze          - Ejecuta el análisis estático de Flutter"
	@echo "  make test             - Ejecuta la suite de pruebas unitarias"

start:
	npx supabase start

stop:
	npx supabase stop

status:
	npx supabase status

seed:
	npx supabase db reset

reset:
	npx supabase db reset

run-web-local:
	flutter run -d chrome --dart-define=ENV=local

run-web-prod:
	flutter run -d chrome --dart-define=ENV=prod

run-mobile-local:
	flutter run --dart-define=ENV=local

run-mobile-prod:
	flutter run --dart-define=ENV=prod

analyze:
	flutter analyze

test:
	flutter test

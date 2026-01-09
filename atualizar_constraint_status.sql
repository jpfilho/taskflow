-- Script para atualizar a constraint CHECK da coluna status na tabela tasks
-- para incluir CANC e RPAR

-- Remover a constraint antiga se existir
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'tasks_status_check'
    ) THEN
        ALTER TABLE tasks DROP CONSTRAINT tasks_status_check;
        RAISE NOTICE 'Constraint tasks_status_check removida.';
    ELSE
        RAISE NOTICE 'Constraint tasks_status_check não existe.';
    END IF;
END
$$;

-- Adicionar a nova constraint com todos os valores permitidos
ALTER TABLE tasks ADD CONSTRAINT tasks_status_check 
    CHECK (status IN ('ANDA', 'CONC', 'PROG', 'CANC', 'RPAR'));

-- Verificar se a constraint foi criada
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'tasks_status_check';


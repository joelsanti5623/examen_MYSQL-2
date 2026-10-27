-- 1. funcion calcular_valor_pendiente 
DELIMITER //

CREATE FUNCTION calcular_valor_pendiente(total_reserva DECIMAL(10,2), abono DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
   DECLARE saldo_pendiente DECIMAL(10,2);
   SET saldo_pendiente = total_reservas - abono;
   
   -- Evitar valores negativos si el abono supera el total
   IF saldo_pendiente < 0 THEN
        SET saldo_pendiente = 0;
    END IF;
    
    RETURN saldo_pendiente;
END//

DELIMITER ;

-- 2. CONSULTA: Pagos pendientes
-- Muestra los clientes con reservas pendientes de pago (saldo > 0).

SELECT 
  c.cliente AS nombre_cliente,
  r.fecha_reserva,
  r.total AS total_reservas,
  p.abono,
  calcular_valor_pendiente (r.total, p.abono) AS valor_pendiente
  
FROM 
  reservas r
JOIN
   clientes c ON r.id_cliente = c.id_cliente
JOIN 
    pagos p ON r.id_reserva = p.id_reserva
WHERE 
    calcular_valor_pendiente(r.total, p.abono) > 0;

-- 3. VISTA: vista_facturacion_reservas
-- Combina información de clientes, reservas y pagos utilizando la función.
CREATE OR REPLACE VIEW vista_facturacion_reservas AS
SELECT 
    c.nombre AS nombre_cliente,
    r.fecha_reserva,
    r.total AS total_reserva,
    p.abono,
    calcular_valor_pendiente(r.total, p.abono) AS valor_pendiente
FROM 
  reservas r
JOIN
  clientes c ON r.id_cliente = c.id_cliente 
JOIN
  pagos p ON r.id_reservas = p.id_reservas;
  
-- 4. TRIGGER: auditoria_abono_trigger
-- registrar una tabla de auditoria cada insercion o actualizacio de pagos 

CREATE TABLE IF NOT EXISTS auditoria_abono (
id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
id_pago INT,
fecha_movimiento DATETIME,
valor_anterior DECIMAL(10,2),
valor_nuevo DECIMAL(10,2),
usuario VARCHAR(100)
);

DELIMITER ;

CREATE TRIGGER auditar_abono_trigger
AFTER INSERT ON pagos
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_abonos (id_pago, fecha_movimiento, valor_anterior, valor_nuevo, usuario)
    VALUES (NEW.id_pago, NOW(), 0.00, NEW.abono, USER())
END//

CREATE TRIGGER auditar_abono_trigger_update
AFTER UPDATE ON pagos
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_abonos (id_pago, fecha_movimiento, valor_anterior, valor_nuevo, usuario)
    VALUES (NEW.id_pago, NOW(), OLD.abono, NEW.abono, USER())
END//

DELIMITER ;



-- 5. CONSULTA: Top clientes cumplidos
-- Muestra los 3 clientes con más reservas pagadas completamente (sin saldo).

SELECT 
    c.nombre AS nombre_cliente,
    COUNT(r.id_reserva) AS reservas_completadas
FROM 
    reservas r
JOIN 
    clientes c ON r.id_cliente = c.id_cliente
JOIN 
    pagos p ON r.id_reserva = p.id_reserva
WHERE 
    calcular_valor_pendiente(r.total, p.abono) = 0
GROUP BY 
    c.id_cliente, c.nombre
ORDER BY 
    reservas_completadas DESC
LIMIT 3;

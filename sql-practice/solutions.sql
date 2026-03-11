-- 1
select * from employees;

-- 2
select * from employees where salary > 70000;

-- 3
select * from employees where hire_date > '2022-01-01';

-- 4
select name, salary from employees order by salary desc;

-- 5
select distinct city from customers ;

-- 6
select count (*) from employees e ;

--7
select Round(avg(salary),2) from employees;

--8
select * from employees where "name" like 'A%';

--9
select * from employees order by salary desc limit 5;

--10
select * from employees where salary >= 50000 and salary <= 90000;

--11
select e."name" , d.department_name from employees e left join departments d on e.department_id = d.department_id; 

--12  SQL is declarative, not procedural. You tell the database what you want, not how to get it.
SELECT d.department_name, COUNT(e.emp_id) as cnt
FROM Departments d
LEFT JOIN Employees e ON d.department_id = e.department_id
GROUP BY d.department_name;

--13
SELECT d.department_name, COUNT(e.emp_id) as cnt
FROM Departments d
JOIN Employees e ON d.department_id = e.department_id
GROUP BY d.department_name
HAVING COUNT(e.emp_id) > 5;

--14
select customer_id , sum(amount) from orders group by customer_id;

--15  
-- customers left join orders imply there can be multiple rows if a customer had multiple orders as well a customer also have atleast one row where he will be mapped to null(in case no order).
  SELECT c.customer_name 
  FROM Customers c 
  LEFT JOIN Orders o ON c.customer_id = o.customer_id 
  WHERE o.order_id IS NULL;

--16
SELECT d.department_name, MAX(e.salary) as max_salary
FROM Departments d
JOIN Employees e ON d.department_id = e.department_id
GROUP BY d.department_name;

-- 17
select
	"name"
from
	employees
where
	salary > (
	select
		AVG(salary)
	from
		employees);

--18
select distinct salary from employees order by employees.salary desc limit 1 offset 1

--19
select department_id , Round(avg(salary),2) avg_salary from  employees group by department_id order by avg(salary) desc limit 3

--20
select o.order_id, o.order_date , c.customer_name , o.amount  from orders o left join customers c on c.customer_id = o.customer_id;

--21 employees must have mangers
SELECT e.name 
FROM Employees e 
JOIN Employees m ON e.manager_id = m.emp_id 
WHERE e.salary > m.salary;


--22 if n == k
  SELECT DISTINCT salary 
  FROM Employees 
  ORDER BY salary DESC 
  LIMIT 1 OFFSET N-1;

--23

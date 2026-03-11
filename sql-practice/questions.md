# SQL Interview Practice Questions (30)

This list progresses from **basic → intermediate → advanced** SQL topics
commonly used in technical interviews.

## Sample Tables Assumed

``` sql
Employees(emp_id, name, department_id, salary, manager_id, hire_date)
Departments(department_id, department_name)
Orders(order_id, customer_id, order_date, amount)
Customers(customer_id, customer_name, city)
Products(product_id, product_name, price, category_id)
OrderItems(order_id, product_id, quantity)
```

------------------------------------------------------------------------

# 1. Basic SQL (Foundation)

These questions test your understanding of **SELECT, filtering, sorting,
and aggregation**.

1.  Retrieve all employees from the `Employees` table.

2.  Find employees who earn **more than 70,000**.

3.  Retrieve employees who were hired **after 2022-01-01**.

4.  Get employee names and salaries sorted by **salary descending**.

5.  Find the **distinct cities** of customers.

6.  Count the **total number of employees**.

7.  Find the **average salary** of employees.

8.  Retrieve employees whose name **starts with 'A'**.

9.  Get the **top 5 highest-paid employees**.

10. Retrieve employees whose salary is **between 50,000 and 90,000**.

------------------------------------------------------------------------

# 2. Intermediate SQL (Joins + Grouping)

These questions test your understanding of **JOINs and aggregations**.

11. Retrieve employee names along with their **department names**.

12. Find the **total number of employees in each department**.

13. Find departments that have **more than 5 employees**.

14. Find the **total order amount for each customer**.

15. Retrieve customers who **never placed an order**.

16. Find the **highest salary in each department**.

17. Find employees who earn **more than the average salary**.

18. Find the **second highest salary** in the Employees table.

19. Find the **top 3 departments with highest average salary**.

20. List all orders along with the **customer name**.

------------------------------------------------------------------------

# 3. Advanced SQL (Subqueries + Window Functions)

These questions commonly appear in **product-company interviews**.

21. Find employees who earn **more than their manager**.

22. Retrieve the **Nth highest salary**.

23. Find the **running total of order amounts** by order date.

24. Rank employees by salary within each department.

25. Find employees who share the **same salary as someone else**.

26. Retrieve the **most expensive product in each category**.

27. Find customers who placed **orders on consecutive days**.

28. Find the **department with the highest total salary**.

29. Find the **percentage contribution of each employee's salary within
    their department**.

30. Find the **most frequently ordered product**.

------------------------------------------------------------------------

# Bonus: Real Interview-Style Problems

These types frequently appear in **Amazon / Google / Uber SQL
interviews**.

-   Detect **duplicate rows in a table**
-   Find **gaps in date sequences**
-   Find users who **logged in 3 consecutive days**
-   Calculate **rolling averages**
-   Identify **top-selling product per month**

------------------------------------------------------------------------

# Suggested SQL Revision Strategy

  Day     Focus
  ------- -----------------------------
  Day 1   SELECT, WHERE, ORDER BY
  Day 2   GROUP BY, HAVING
  Day 3   JOINs
  Day 4   Subqueries
  Day 5   Window Functions
  Day 6   Advanced Interview Problems


```SQL
CREATE TABLE Departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL
);

CREATE TABLE Employees (
    emp_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department_id INT,
    salary DECIMAL(10,2),
    manager_id INT,
    hire_date DATE,

    FOREIGN KEY (department_id) REFERENCES Departments(department_id),
    FOREIGN KEY (manager_id) REFERENCES Employees(emp_id)
);

CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    city VARCHAR(100)
);

CREATE TABLE Orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    amount DECIMAL(10,2),

    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2),
    category_id INT
);


CREATE TABLE OrderItems (
    order_id INT,
    product_id INT,
    quantity INT,

    PRIMARY KEY (order_id, product_id),

    FOREIGN KEY (order_id) REFERENCES Orders(order_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

CREATE INDEX idx_emp_department ON Employees(department_id);
CREATE INDEX idx_emp_manager ON Employees(manager_id);

CREATE INDEX idx_orders_customer ON Orders(customer_id);
CREATE INDEX idx_orders_date ON Orders(order_date);

CREATE INDEX idx_orderitems_product ON OrderItems(product_id);


INSERT INTO Departments (department_id, department_name) VALUES
(1, 'Engineering'),
(2, 'Sales'),
(3, 'Marketing'),
(4, 'HR'),
(5, 'Finance'),
(6, 'Support');

INSERT INTO Employees (emp_id, name, department_id, salary, manager_id, hire_date) VALUES
(1, 'Alice', 1, 120000, NULL, '2018-03-10'),
(2, 'Bob', 1, 90000, 1, '2019-07-21'),
(3, 'Charlie', 1, 90000, 1, '2020-01-15'),
(4, 'David', 2, 75000, NULL, '2017-11-05'),
(5, 'Eva', 2, 60000, 4, '2021-04-11'),
(6, 'Frank', 2, 60000, 4, '2022-09-01'),
(7, 'Grace', 3, 80000, NULL, '2019-05-19'),
(8, 'Hannah', 3, 55000, 7, '2023-02-10'),
(9, 'Ian', 4, 70000, NULL, '2016-08-30'),
(10, 'Jack', 4, 45000, 9, '2022-10-12'),
(11, 'Karen', 5, 95000, NULL, '2020-12-01'),
(12, 'Leo', 5, 50000, 11, '2023-06-22'),
(13, 'Mia', 1, 105000, 1, '2021-09-15'),
(14, 'Nina', 3, 55000, 7, '2022-03-17'),
(15, 'Oscar', 2, 58000, 4, '2023-01-10');


INSERT INTO Customers (customer_id, customer_name, city) VALUES
(1, 'John Doe', 'New York'),
(2, 'Jane Smith', 'London'),
(3, 'Michael Brown', 'Toronto'),
(4, 'Emily Davis', 'Sydney'),
(5, 'Daniel Wilson', 'Berlin'),
(6, 'Sophia Lee', 'Tokyo'),
(7, 'Carlos Gomez', 'Madrid');



INSERT INTO Products (product_id, product_name, price, category_id) VALUES
(1, 'Laptop', 1200, 1),
(2, 'Smartphone', 800, 1),
(3, 'Tablet', 600, 1),
(4, 'Headphones', 150, 2),
(5, 'Keyboard', 100, 2),
(6, 'Mouse', 50, 2),
(7, 'Monitor', 300, 3),
(8, 'Printer', 200, 3);


INSERT INTO Orders (order_id, customer_id, order_date, amount) VALUES
(101, 1, '2024-01-01', 1200),
(102, 2, '2024-01-01', 800),
(103, 1, '2024-01-02', 150),
(104, 3, '2024-01-03', 600),
(105, 4, '2024-01-05', 300),
(106, 5, '2024-01-05', 450),
(107, 1, '2024-01-07', 200),
(108, 2, '2024-01-08', 100),
(109, 3, '2024-01-10', 700),
(110, 4, '2024-01-10', 400);

INSERT INTO OrderItems (order_id, product_id, quantity) VALUES
(101, 1, 1),
(102, 2, 1),
(103, 4, 1),
(103, 6, 2),
(104, 3, 1),
(105, 7, 1),
(106, 4, 3),
(107, 8, 1),
(108, 5, 1),
(109, 1, 1),
(110, 7, 2);
```
**SQL Ranking Functions Overview**

| Function | Description | Tie Handling Example (Scores 90, 80, 80, 70) |
| --- | --- | --- |
| ```ROW_NUMBER()``` | Assigns a unique, sequential number to each row, starting from 1. It does not consider ties; every row gets a different number. | 1, 2, 3, 4 |
| ```RANK()``` | Assigns the same rank to tied values but skips the next rank(s) in the sequence, creating gaps. | 1, 2, 2, 4 (rank 3 is skipped) |
| ```DENSE_RANK()``` | Assigns the same rank to tied values but does not skip any ranks, ensuring a continuous sequence. | 1, 2, 2, 3 (no gaps) |
| ```NTILE(n)``` | Divides the result set into a specified number of () approximately equal groups, assigning a group number (or bucket) to each row. | for 4 rows: 1, 1, 2, 2 (approximate grouping) |

Example:

```sql
SELECT 
    employee_id,
    salary,
    ROW_NUMBER() OVER (ORDER BY salary DESC) AS row_num,
    RANK() OVER (ORDER BY salary DESC) AS rank_num,
    DENSE_RANK() OVER (ORDER BY salary DESC) AS dense_rank_num
FROM employees;
```

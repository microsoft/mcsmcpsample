from dataclasses import dataclass
from enum import StrEnum
from types import MappingProxyType
from typing import Final


@dataclass(frozen=True, slots=True)
class Customer:
    customer_number: str
    name: str
    phone_number: str
    email: str


@dataclass(frozen=True, slots=True)
class CustomerList:
    customers: tuple[Customer, ...]


class DemoUser(StrEnum):
    JAMES = "James"
    JANE = "Jane"
    BILL = "Bill"


CUSTOMERS: Final = (
    Customer("CUST-1001", "Imaginary Rocket Company", "+1-202-555-0101", "rocket@example.com"),
    Customer("CUST-1002", "Fictional Moonbase Supplies", "+1-202-555-0102", "moonbase@example.com"),
    Customer(
        "CUST-1003",
        "Example Time Travel Agency",
        "+1-202-555-0103",
        "time-travel@example.com",
    ),
    Customer(
        "CUST-1004",
        "Placeholder Cloud Castle Logistics",
        "+1-202-555-0104",
        "cloud-castle@example.com",
    ),
)

ACCESS_MATRIX: Final = MappingProxyType(
    {
        DemoUser.JAMES: frozenset({"CUST-1001", "CUST-1002"}),
        DemoUser.JANE: frozenset({"CUST-1003", "CUST-1004"}),
        DemoUser.BILL: frozenset(),
    }
)

_CUSTOMERS_BY_NUMBER: Final = MappingProxyType(
    {customer.customer_number: customer for customer in CUSTOMERS}
)


def list_customers(allowed_customer_numbers: frozenset[str] | None) -> CustomerList:
    """Return customers in stable catalog order; None grants trusted-mode access."""
    if allowed_customer_numbers is None:
        return CustomerList(CUSTOMERS)

    return CustomerList(
        tuple(
            customer
            for customer in CUSTOMERS
            if customer.customer_number in allowed_customer_numbers
        )
    )


def get_customer(
    customer_number: str, allowed_customer_numbers: frozenset[str] | None
) -> Customer | None:
    """Return None for both inaccessible and nonexistent customer numbers."""
    if allowed_customer_numbers is not None and customer_number not in allowed_customer_numbers:
        return None
    return _CUSTOMERS_BY_NUMBER.get(customer_number)

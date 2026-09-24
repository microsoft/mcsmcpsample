from pydantic import BaseModel, ConfigDict

from mcmc_mcp.customers import Customer, CustomerList


class CustomerResult(BaseModel):
    model_config = ConfigDict(frozen=True)

    customer_number: str
    name: str
    phone_number: str
    email: str

    @classmethod
    def from_customer(cls, customer: Customer) -> "CustomerResult":
        return cls(
            customer_number=customer.customer_number,
            name=customer.name,
            phone_number=customer.phone_number,
            email=customer.email,
        )


class CustomerListResult(BaseModel):
    model_config = ConfigDict(frozen=True)

    customers: tuple[CustomerResult, ...]

    @classmethod
    def from_customer_list(cls, customer_list: CustomerList) -> "CustomerListResult":
        return cls(
            customers=tuple(
                CustomerResult.from_customer(customer) for customer in customer_list.customers
            )
        )


class CustomerLookupResult(BaseModel):
    model_config = ConfigDict(frozen=True)

    customer: CustomerResult | None

    @classmethod
    def from_customer(cls, customer: Customer | None) -> "CustomerLookupResult":
        return cls(customer=CustomerResult.from_customer(customer) if customer else None)

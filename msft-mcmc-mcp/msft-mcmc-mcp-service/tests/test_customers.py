import re
import unittest

from mcmc_mcp.customers import (
    ACCESS_MATRIX,
    CUSTOMERS,
    DemoUser,
    get_customer,
    list_customers,
)


class CustomerCatalogTests(unittest.TestCase):
    def test_customer_contact_data_is_reserved_and_obviously_fictitious(self) -> None:
        fictional_name_markers = {"Imaginary", "Fictional", "Example", "Placeholder"}

        self.assertEqual(len({customer.customer_number for customer in CUSTOMERS}), len(CUSTOMERS))
        for customer in CUSTOMERS:
            self.assertTrue(any(marker in customer.name for marker in fictional_name_markers))
            self.assertRegex(customer.phone_number, re.compile(r"^\+1-202-555-01\d{2}$"))
            self.assertTrue(customer.email.endswith("@example.com"))

    def test_access_matrix_has_disjoint_expected_subsets(self) -> None:
        self.assertEqual(ACCESS_MATRIX[DemoUser.JAMES], {"CUST-1001", "CUST-1002"})
        self.assertEqual(ACCESS_MATRIX[DemoUser.JANE], {"CUST-1003", "CUST-1004"})
        self.assertEqual(ACCESS_MATRIX[DemoUser.BILL], set())
        self.assertTrue(ACCESS_MATRIX[DemoUser.JAMES].isdisjoint(ACCESS_MATRIX[DemoUser.JANE]))

    def test_list_is_deterministic_and_filtered(self) -> None:
        first = list_customers(ACCESS_MATRIX[DemoUser.JAMES])
        second = list_customers(ACCESS_MATRIX[DemoUser.JAMES])

        self.assertEqual(first, second)
        self.assertEqual(
            tuple(customer.customer_number for customer in first.customers),
            ("CUST-1001", "CUST-1002"),
        )
        self.assertEqual(list_customers(ACCESS_MATRIX[DemoUser.BILL]).customers, ())

    def test_inaccessible_and_nonexistent_lookups_are_indistinguishable(self) -> None:
        james_access = ACCESS_MATRIX[DemoUser.JAMES]

        self.assertIsNone(get_customer("CUST-1003", james_access))
        self.assertIsNone(get_customer("CUST-9999", james_access))

    def test_trusted_mode_can_access_the_complete_catalog(self) -> None:
        self.assertEqual(list_customers(None).customers, CUSTOMERS)
        self.assertEqual(get_customer("CUST-1004", None), CUSTOMERS[3])


if __name__ == "__main__":
    unittest.main()
